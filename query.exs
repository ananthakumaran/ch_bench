{:ok, channel} =
  GRPC.Stub.connect("localhost:9100", interceptors: [GRPC.Client.Interceptors.Logger])

request = Clickhouse.Grpc.QueryInfo.new(query: "select 1")

{:ok, reply} = Clickhouse.Grpc.ClickHouse.Stub.execute_query(channel, request)

# # pass tuple `timeout: :infinity` as a second arg to stay in IEx debugging

IO.inspect(reply)
