import ByMove

defmove Receiver do

  def receive_move() do
    receive do
      {_, func} ->
        ByMove.insert_func_load(@ast, func)
      _ ->
        IO.puts("Invalid message")
    end
  end

  def getAst() do
    @ast
  end
end
