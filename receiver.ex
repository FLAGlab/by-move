import ByMove

defmove Receiver do

  def receive_move() do
    receive do
      {_, func} ->
        ByMove.insert_func_load(@ast, func)
      x ->
        IO.puts(x)
      _ ->
        IO.puts("idk")
    end
  end

  def getAst() do
    @ast
  end
end
