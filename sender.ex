import ByMove

defmove Sender do


  def adder(a,b) do
    a+b
  end

  def multiplier(a,b) do
    a*b
  end

  def send_move(dest) do
    ByMove.send_by_move(dest, {:adder, 2})
  end

  def getDirectory() do
    __ENV__.file()
  end

  def getAst() do
    @ast
  end

  # def delete_adder() do
  #   Module.delete_definition(Sender, {:adder, 2})
  # end
end
