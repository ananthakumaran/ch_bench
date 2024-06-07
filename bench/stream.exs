IO.puts("This benchmark is based on https://github.com/ClickHouse/ch-bench\n")

port = String.to_integer(System.get_env("CH_PORT") || "8123")
hostname = System.get_env("CH_HOSTNAME") || "localhost"
scheme = System.get_env("CH_SCHEME") || "http"

{:ok, conn} = Ch.start_link(scheme: scheme, hostname: hostname, port: port)

{:ok, channel} = GRPC.Stub.connect("localhost:9100", interceptors: [])

Benchee.run(
  %{
    "http stream" => fn limit ->
      DBConnection.run(
        conn,
        fn conn ->
          conn
          |> Ch.stream(
            "SELECT number FROM system.numbers_mt LIMIT {limit:UInt64} FORMAT RowBinary",
            %{"limit" => limit}
          )
          |> Stream.with_index()
          |> Stream.map(fn {%Ch.Result{data: data}, i} ->
            data
            |> IO.iodata_to_binary()
            |> Ch.RowBinary.decode_rows([:u64])
          end)
          |> Stream.run()
        end,
        timeout: :infinity
      )
    end,
    "grpc stream" => fn limit ->
      request = %Clickhouse.Grpc.QueryInfo{
        query: "SELECT number FROM system.numbers_mt LIMIT #{limit} FORMAT RowBinary"
      }

      {:ok, stream} =
        Clickhouse.Grpc.ClickHouse.Stub.execute_query_with_stream_output(channel, request)

      Stream.with_index(stream)
      |> Stream.map(fn {{:ok, reply}, i} ->
        Ch.RowBinary.decode_rows(reply.output, [:u64])
      end)
      |> Stream.run()
    end
  },
  inputs: %{
    "5_000_000 rows" => 5_000_000,
    "10_000_000 rows" => 10_000_000
  }
)
