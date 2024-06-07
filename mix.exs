defmodule ChBench.MixProject do
  use Mix.Project

  def project do
    [
      app: :ch_bench,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:benchee, "~> 1.0", only: :dev},
      {:ch, "~> 0.2.0"},
      {:grpc, "~> 0.8"},
      {:protobuf, "~> 0.11"},
      {:protobuf_generate, "~> 0.1.1", only: [:dev, :test]},
      {:recon, "~> 2.5"}
    ]
  end

  defp aliases do
    [
      generate:
        "protobuf.generate --output-path=./lib --include-path=./priv/protos --generate-descriptors=true --plugins=ProtobufGenerate.Plugins.GRPC clickhouse_grpc.proto"
    ]
  end
end
