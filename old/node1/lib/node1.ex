import ByMove

defmodule Node1 do
  def main_bymove(nodes, db_server) do
    wait_till_start()
    auth = Function.capture(Authentication, :authenticate, 3)
    authenticated? = auth.(db_server, "Alice", "password123")

    if !authenticated? do
      IO.puts("Authentication failed")
      finish()
    end

    if !ByMove.has_func?(Authentication, {:get_balance, 2}) do
      ByMove.i_need_func({:get_balance, 2}, nodes, self())
      IO.puts("Waiting for get_balance")
      ByMove.module_wait_for_func(Authentication,{:get_balance, 2}, nodes, self(), [])
    end

    IO.puts("has func get_balance")
    get_balance = Function.capture(Authentication, :get_balance, 2)

    balance = get_balance.(db_server, "Alice")
    if balance < 50 do
      IO.puts("Insufficient funds")
      finish()
    end

    if !ByMove.has_func?(Authentication, {:withdraw, 3}) do
      IO.puts "Waiting for withdraw"
      ByMove.i_need_func({:withdraw, 3}, nodes, self())
      ByMove.module_wait_for_func(Authentication, {:withdraw, 3}, nodes, self(), [])
    end
    IO.puts "has func withdraw"

    withdraw = Function.capture(Authentication, :withdraw, 3)
    new_balance = withdraw.(db_server, "Alice", 50)
    IO.puts("New balance: #{new_balance}")
    mark_done(db_server)
    finish()
  end

  def server() do
    db_server = :global.whereis_name(:database)
    receive do
      {:authenticate, user, password, from_pid} ->
        authenticated? = Authentication.authenticate(db_server, user, password)
        send(from_pid, authenticated?)
      _ ->
        IO.puts("Unknown message")
    end
    server()
  end

  def main_standard(nodes, db_server) do
    wait_till_start()

    users_pid = nodes |> Enum.at(0)
    transaction_pid = nodes |> Enum.at(1)

    auth = Authentication.authenticate(db_server, "Alice", "password123")

    if !auth do
      IO.puts("Authentication failed")
    end

    send(users_pid, {:get_balance, "Alice", self()})
    balance = receive do
      balance -> balance
    end

    if balance < 50 do
      IO.puts("Insufficient funds")
    end

    send(transaction_pid, {:withdraw, "Alice", 50, self()})
    new_balance = receive do
      new_balance -> new_balance
    end

    IO.puts("New balance: #{new_balance}")
    mark_done(db_server)
  end

  def wait_till_start do
    if :global.whereis_name(:ready) == :undefined do
      wait_till_start()
    end
  end



  def finish() do
    IO.puts "releasing functions"
    ByMove.module_release_functions(Authentication)
  end

  def mark_done(db_server) do
    :global.register_name(:node1_done, db_server)
  end

end


defmove Authentication do

  def setup(test) do
    Toolshed.cmd("epmd -daemon")
    Node.start(:"node1@192.168.0.13")
    Node.set_cookie(:mycookie)
    Node.connect(:"database@192.168.0.9")
    if test==:bymove do
      :global.register_name :node1, self()
    else
      :global.register_name :node1, spawn(fn -> Node1.server() end)
    end
  end

  def setup2() do
    node3 = :global.whereis_name(:node3)
    node2 = :global.whereis_name(:node2)
    db_server = :global.whereis_name(:database)
    nodes = [node2, node3]
    {nodes, db_server}
  end



  def authenticate(db_server, user, password) do
    hashed = String.reverse(password)
    GenServer.call(db_server, {:authenticate, user, hashed})
  end

  def finish() do
    ByMove.release_functions()
  end

end
