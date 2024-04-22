import ByMove

defmove Users do
  def main() do
    #TODO
  end

  def get_balance(db_server, user) do
    GenServer.call(db_server, {:get_balance, user})
  end


end
