case System.argv() do
  [] -> ExLox.repl()
  [filename] -> ExLox.run_file(filename)
end
