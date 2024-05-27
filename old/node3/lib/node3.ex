import ByMove

defmodule Node3 do
  def main_bymove(nodes, db_server) do
    wait_till_start()

    if !ByMove.have_func?(Transaction, {:authenticate, 3}) do
      ByMove.i_need_func({:authenticate, 3}, nodes, self())
      ByMove.module_wait_for_func(Transaction,{:authenticate, 3}, nodes, self())
    end

    authenticate = Function.capture(Transaction, :authenticate, 3)
    authenticated? = authenticate.(db_server, "Alice", "password123")

    if !authenticated? do
      IO.puts("Authentication failed")
      finish()
    end

    if !ByMove.have_func?(Transaction,{:get_balance, 2}) do
      IO.puts "Waiting for get_balance"
      ByMove.i_need_func({:get_balance, 2}, nodes, self())
      ByMove.module_wait_for_func(Transaction,{:get_balance, 2}, nodes, self(), [])
    end

    get_balance = Function.capture(Transaction, :get_balance, 2)
    balance = get_balance.(db_server, "Alice")

    if balance < 50 do
      IO.puts("Insufficient funds")
      finish()
    end

    if !ByMove.have_func?(Transaction,{:withdraw, 3}) do
      IO.puts "Waiting for withdraw"
      ByMove.i_need_func({:withdraw, 3}, nodes, self())
      ByMove.module_wait_for_func(Transaction,{:withdraw, 3}, nodes, self(), [])
    end

    IO.puts "has func withdraw"
    withdraw = Function.capture(Transaction, :withdraw, 3)

    if !ByMove.have_func?(Transaction,{:deposit, 3}) do
      IO.puts "Waiting for deposit"
      ByMove.i_need_func({:deposit, 3}, nodes, self())
      ByMove.module_wait_for_func(Transaction, {:deposit, 3}, nodes, self(), [{:withdraw, 3}])
    end

    IO.puts "has func deposit"
    deposit = Function.capture(Transaction, :deposit, 3)

    transaction = Function.capture(Transaction, :transaction, 6)
    transaction.(db_server, "Alice", "Bob", 100, withdraw, deposit)

    mark_done(db_server)
    finish()
  end

  def server do
    db_server = :global.whereis_name(:database)
    receive do
      {:withdraw, user, amount, from_pid} ->
        new_balance = Transaction.withdraw(db_server, user, amount)
        send(from_pid, new_balance)
      {:deposit, user, amount, from_pid} ->
        new_balance = Transaction.deposit(db_server, user, amount)
        send(from_pid, new_balance)
      _ -> IO.puts("Unknown message")
    end
    server()
  end

  def mainStandard(nodes, db_server) do
    wait_till_start()

    authentication_pid = nodes |> Enum.at(0)
    get_balance_pid = nodes |> Enum.at(1)

    # authenticate, get_balance, withdraw, deposit

    send(authentication_pid, {:authenticate, db_server, "Alice", "password123", self()})
    authentication_result = receive do
      authentication_result -> authentication_result
    end

    if !authentication_result do
      IO.puts("Authentication failed")
    end

    send(get_balance_pid, {:get_balance, db_server, "Alice", self()})
    balance = receive do
      balance -> balance
    end

    if balance < 50 do
      IO.puts("Insufficient funds")
    end

    IO.puts "here"
    Transaction.transaction(db_server, "Alice", "Bob", 100, &Transaction.withdraw/3, &Transaction.deposit/3)
    IO.puts "done"
    mark_done(db_server)
  end

  def wait_till_start do
    if :global.whereis_name(:ready) == :undefined do
      wait_till_start()
    end
  end

  def finish() do
    IO.puts "releasing functions"
    ByMove.module_release_functions(Transaction)
  end


  def mark_done(db_server) do
    :global.register_name(:node3_done, db_server)
  end
end

defmove Transaction do

  def setup(test) do
    Toolshed.cmd("epmd -daemon")
    Node.start(:"node3@192.168.0.14")
    Node.set_cookie(:mycookie)
    Node.connect(:"database@192.168.0.9")
    if test==:bymove do
      :global.register_name :node3, self()
    else
      :global.register_name :node3, spawn(fn -> Node3.server() end)
    end
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
