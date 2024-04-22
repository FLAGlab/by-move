defmove Transactions do
  def main() do
    #TODO
  end

  def transaction(db_server, user1, user2, amount, withdraw_func, deposit_func) do
    withdraw_func.(db_server, user1, amount)
    deposit_func.(db_server, user2, amount)
  end
end
