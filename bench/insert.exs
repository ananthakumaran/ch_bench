port = String.to_integer(System.get_env("CH_PORT") || "8123")
hostname = System.get_env("CH_HOSTNAME") || "localhost"
scheme = System.get_env("CH_SCHEME") || "http"
database = System.get_env("CH_DATABASE") || "ch_bench"

{:ok, conn} = Ch.start_link(scheme: scheme, hostname: hostname, port: port, pool_size: 4)

Ch.query!(conn, "CREATE DATABASE IF NOT EXISTS {$0:Identifier}", [database])

Ch.query!(conn, """
CREATE TABLE IF NOT EXISTS #{database}.benchmark (
  col1 UInt64,
  col2 String,
  col3 Array(UInt8),
  col4 DateTime
) Engine MergeTree
ORDER BY (col1)
""")

types = [Ch.Types.u64(), Ch.Types.string(), Ch.Types.array(Ch.Types.u8()), Ch.Types.datetime()]
statement = "INSERT INTO #{database}.benchmark FORMAT RowBinary"

read_statement =
  "SELECT col1,col2,col3,col4 from #{database}.benchmark limit 100 FORMAT RowBinary"

rows = fn count ->
  Enum.map(1..count, fn i ->
    [i, "Golang SQL database driver", [1, 2, 3, 4, 5, 6, 7, 8, 9], NaiveDateTime.utc_now()]
  end)
end

{:ok, channel} = GRPC.Stub.connect("localhost:9100", interceptors: [])

alias Ch.RowBinary

Benchee.run(
  %{
    "insert http" => fn rows -> Ch.query!(conn, statement, rows, types: types) end,
    "insert grpc" => fn rows ->
      data = RowBinary.encode_rows(rows, types) |> IO.iodata_to_binary()
      request = %Clickhouse.Grpc.QueryInfo{query: statement, input_data: data}

      {:ok,
       %Clickhouse.Grpc.Result{
         progress: %Clickhouse.Grpc.Progress{
           written_rows: 100
         }
       }} = Clickhouse.Grpc.ClickHouse.Stub.execute_query(channel, request)
    end,
    "read grpc" => fn rows ->
      request = %Clickhouse.Grpc.QueryInfo{query: read_statement}
      {:ok, result} = Clickhouse.Grpc.ClickHouse.Stub.execute_query(channel, request)

      RowBinary.decode_rows(result.output, [
        Ch.Types.u64(),
        Ch.Types.string(),
        Ch.Types.array(Ch.Types.u8()),
        Ch.Types.datetime("UTC")
      ])
    end,
    "read http" => fn _ ->
      Ch.query!(conn, read_statement, [],
        types: [
          Ch.Types.u64(),
          Ch.Types.string(),
          Ch.Types.array(Ch.Types.u8()),
          Ch.Types.datetime("UTC")
        ]
      )
    end
  },
  # profile_after: :fprof,
  parallel: 4,
  inputs: %{
    "100 rows" => rows.(100)
  }
)
