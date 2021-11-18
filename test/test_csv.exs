defmodule TestCSV do
  NimbleCSV.define(CSV, separator: ",", escape: "\"")
  require Logger


  def main(csv_files) do
    {:ok, _pid} = KeyLoader.start_link()
    for csv_file <- csv_files do
      Logger.info("Handling CSV file #{csv_file}")
      # ask for key preloads
      csv_file
      |> parse_export()
      |> Stream.chunk(1000)
      |> Enum.each(fn chunk ->
        # preload for chunk
        chunk
        |> Stream.map(fn [m,s,_] -> {m,s} end)
        |> Enum.each(fn {m,s} -> KeyLoader.preload_keys(m, s) end)

        # wait until preloaded
        KeyLoader.wait_until_ready()
        # handle chunk lines
        Enum.map(chunk, &handle_csv_line/1)
      end)
    end
  end

  defp parse_export(filename) do
    filename
    |> File.stream!()
    |> CSV.parse_stream(skip_headers: false)
  end

  defp handle_csv_line([expected_manufacturer, expected_serial, hexdata]) do
    try do
      IO.write(".")
      hexdata
      |> Base.decode16!()
      |> Exmbus.simplified!(length: false, key: Exmbus.Key.by_fn(&get_keys/2))
    rescue
      e ->
        {int_serial, ""} = Integer.parse(expected_serial)
        {:ok, keys} = KeyLoader.get_keys(expected_manufacturer, int_serial)
        hex_keys_str =
          keys
          |> Enum.map(&Exmbus.Debug.bin_to_hex/1)
          |> Enum.join(", ")
        Logger.debug("Failing frame: #{expected_manufacturer} #{expected_serial} keys: #{hex_keys_str} frame: #{hexdata}")
        reraise e, __STACKTRACE__
    end
  end

  def get_keys(_opts, ctx) do
    {manufacturer, serial} =
      Enum.reduce(ctx, nil, fn
        (%Exmbus.Dll.Wmbus{manufacturer: m, identification_no: s}, nil) -> {m, s}
        (_, acc) -> acc
      end)
    KeyLoader.get_keys(manufacturer, serial)
  end
end

defmodule KeyLoader do
  use GenServer
  require Logger

  defstruct [
    base_uri: nil,# base uri when downloading keys
    bearer_token: nil, # token used as bearer token against key system
    cache: %{}, # %{{m,s} => key} map of cached keys
    pending: %{}, # %{{m,s} => [_from]} map of pending requests
    queue: [], # a list of {m,s} to download next time we try
    download_pid: nil, # the pid of the downloader or nil of no download is running
  ]

  ##
  ## API
  ##

  def start_link() do
    base_uri = System.get_env("BASE_URI", nil) || raise "No BASE_URI set"
    token = System.get_env("BEARER_TOKEN", nil) || raise "No BEARER_TOKEN set"
    GenServer.start_link(__MODULE__, [base_uri, token], name: __MODULE__)
  end

  def preload_keys(manufacturer, serial) do
    GenServer.cast(__MODULE__, {:preload_keys, {manufacturer, serial}})
  end

  def get_keys(manufacturer, serial) do
    GenServer.call(__MODULE__, {:get_keys, {manufacturer, serial}})
  end

  def wait_until_ready() do
    GenServer.call(__MODULE__, :wait_until_ready, 60_000)
  end

  ##
  ## GenServer callbacks
  ##

  @impl true
  def init([base_uri, token]) do
    {:ok, %__MODULE__{bearer_token: token, base_uri: base_uri}}
  end

  @impl true
  def handle_call({:get_keys, m_s}, from, %{pending: pending, queue: queue}=state) do
    case state.cache do
      %{^m_s => keys} ->
        {:reply, {:ok, keys}, state}
      _ ->
        new_list =
          case pending do
            %{^m_s => existing} -> [from | existing]
            _ -> [from]
          end
        maybe_send_download(state)
        {:noreply, %{state | queue: [m_s | queue], pending: Map.put(pending, m_s, new_list)}}
    end
  end

  def handle_call(:wait_until_ready, _from, %{queue: [], download_pid: nil}=state) do
    {:reply, :ok, state}
  end
  def handle_call(:wait_until_ready, from, %{}=state) do
    send(self(), {:wait_until_ready, from})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:preload_keys, m_s}, %{pending: pending, queue: queue}=state) do
    case pending do
      # manufacturer+serial already pending, ignore preload request
      %{^m_s => _} ->
        {:noreply, state}
      # not already pending, add it to queue and ask for download
      _ ->
        maybe_send_download(state)
        {:noreply, %{state | queue: [m_s | queue]}}
    end
  end

  @impl true
  def handle_info({:downloaded, pid, old_queue, resp}, %{pending: pending, download_pid: pid}=state) do
    Logger.debug("downloaded for #{Enum.count(old_queue)} pairs")
    # something was downloaded, first insert into cache
    cache =
      resp
      |> Enum.reduce(state.cache, fn
        ({m_s, keys}, cache) ->
          keys =
            case cache do
              %{^m_s => existing} -> Enum.uniq(keys ++ existing)
              _ -> keys
            end
          Map.put(cache, m_s, keys)
      end)
    # find all resolved entries
    {resolved, pending} = Map.split(pending, old_queue)
    # send reply to resolved
    resolved
    |> Enum.each(fn {m_s, froms} ->
      Enum.each(froms, fn from ->
        GenServer.reply(from, {:ok, Map.get(cache, m_s)})
      end)
    end)
    # if download queue is not empty, start another download
    if state.queue != [] do
      send(self(), :download)
    end
    # update state
    {:noreply, %{state | download_pid: nil, cache: cache, pending: pending}}
  end
  def handle_info(:download, %{queue: []}=state) do
    Logger.warn("download, but queue empty, doing nothing")
    # asked to download but queue empty. noop
    {:noreply, state}
  end
  def handle_info(:download, %{queue: [_|_], download_pid: pid}=state) when pid != nil do
    Logger.warn("download, but download already running, doing nothing")
    {:noreply, state}
  end
  def handle_info(:download, %{queue: [_|_]=queue, download_pid: nil}=state) do
    # queue is >0 and download is not running, start downloader
    parent = self()
    {download_queue, new_queue} = Enum.split(queue, 1000)
    bearer = state.bearer_token || raise "missing bearer_token from state"
    base_uri = state.base_uri || raise "missing base_uri from state"
    download_pid =
      spawn_link(fn ->
        url = "#{base_uri}/api/meters/search"
        body =
          %{meters: Enum.map(download_queue, fn {m,s} -> %{manufacturer: m, serial: "#{s}"} end)}
          |> Jason.encode!()
        headers = [
          {"Content-Type", "application/json"},
          {"Authorization", "bearer #{bearer}"},
        ]
        case HTTPoison.post(url, body, headers) do
          {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
            case Jason.decode!(body) do
              %{"result" => result} ->
                response =
                  result
                  |> Enum.map(fn %{"manufacturer" => m, "serial" => s, "keys" => keys} ->
                    {s, ""} = Integer.parse(s)
                    {{m, s}, Enum.map(keys, &Base.decode16!/1)}
                  end)
                  |> Enum.into(%{})

                send(parent, {:downloaded, self(), download_queue, response})
            end
        end
      end)
    {:noreply, %{state | queue: new_queue, download_pid: download_pid}}
  end
  def handle_info({:wait_until_ready, from}, %{queue: [], download_pid: nil}=state) do
    GenServer.reply(from, :ok)
    {:noreply, state}
  end
  def handle_info({:wait_until_ready, _from}=q, state) do
    Process.send_after(self(), q, 50) #hacky. can't be bothered implementing this correctly.
    {:noreply, state}
  end

  # if queue was empty and download pid was not set, schedule download
  defp maybe_send_download(%{queue: [], download_pid: nil}), do: send(self(), :download)
  defp maybe_send_download(%{}), do: nil


end


TestCSV.main(System.argv())


