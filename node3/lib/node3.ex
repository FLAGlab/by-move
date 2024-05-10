import ByMove

defmodule Node3 do
  def main(nodes, db_server) do
    wait_till_start()

    if !ByMove.have_func?(Transaction, {:authenticate, 3}) do
      ByMove.i_need_func({:authenticate, 3}, nodes, self())
      ByMove.module_wait_for_func(Transaction,{:authenticate, 3})
    end

    authenticate = Function.capture(Transaction, :authenticate, 3)
    authenticated? = authenticate.(db_server, "Alice", "password123")

    if !authenticated? do
      IO.puts("Authentication failed")
      finish()
    end

    if !ByMove.have_func?(Transaction,{:get_balance, 2}) do
      ByMove.i_need_func({:get_balance, 2}, nodes, self())
      ByMove.module_wait_for_func(Transaction,{:get_balance, 2})
    end

    get_balance = Function.capture(Transaction, :get_balance, 2)
    balance = get_balance.(db_server, "Alice")

    if balance < 50 do
      IO.puts("Insufficient funds")
      finish()
    end

    if !ByMove.have_func?(Transaction,{:withdraw, 3}) do
      ByMove.i_need_func({:withdraw, 3}, nodes, self())
      ByMove.module_wait_for_func(Transaction,{:withdraw, 3})
    end

    withdraw = Function.capture(Transaction, :withdraw, 3)

    if !ByMove.have_func?(Transaction,{:deposit, 3}) do
      ByMove.i_need_func({:deposit, 3}, nodes, self())
      ByMove.module_wait_for_func(Transaction,{:deposit, 3}, [{:withdraw, 3}])
    end

    deposit = Function.capture(Transaction, :deposit, 3)

    transaction = Function.capture(Transaction, :transaction, 6)
    transaction.(db_server, "Alice", "Bob", 100, withdraw, deposit)

    finish()
  end

  def wait_till_start do
    if :global.whereis_name(:ready) == :undefined do
      wait_till_start()
    end
  end

  def finish() do
    ByMove.module_release_functions(Transaction)
  end
end

defmove Transaction do

  def setup() do
    Toolshed.cmd("epmd -daemon")
    Node.start(:"node3@192.168.0.15")
    Node.set_cookie(:mycookie)
    Node.connect(:"database@192.168.0.16")
    :global.register_name :node3, self()
  end

  def setup2() do
    node1 = :global.whereis_name(:node1)
    node2 = :global.whereis_name(:node2)
    db_server = :global.whereis_name(:database)
    nodes = [node1, node2]
    {nodes, db_server}
  end


  def transaction(db_server, user1, user2, amount, withdraw_func, deposit_func) do
    withdraw_func.(db_server, user1, amount)
    deposit_func.(db_server, user2, amount)
  end

  def withdraw(db_server, user, amount) do
    GenServer.call(db_server, {:withdraw, user, amount})
  end

  def deposit(db_server, user, amount) do
    GenServer.call(db_server, {:deposit, user, amount})
  end

  def finish() do
    ByMove.release_functions()
  end
end
