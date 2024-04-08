import ByMove

defmove Sender do

  require ByMove
  def adder(a,b) do
    a+b
  end

  def multiplier(a,b) do
    a*b
  end

  def send_move(dest, {func_name, func_arity}) do
    ByMove.send_by_move(dest, {func_name, func_arity})
  end

  def getDirectory() do
    __ENV__.file()
  end

  def getAst() do
    @ast
  end

end
