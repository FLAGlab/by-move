import ByMove

defmodule Node2 do
  def main_bymove(nodes, db_server) do
    wait_till_start()

    if !ByMove.has_func?(Users, {:authenticate, 3}) do
      IO.puts "Waiting for authenticate"
      ByMove.i_need_func({:authenticate, 3}, nodes, self())
      ast_ithink = ByMove.module_wait_for_func(Users, {:authenticate, 3}, nodes, self(), [])
      # IO.inspect(ast_ithink)
    end

    IO.puts "has func authenticate"
    authenticate = Function.capture(Users, :authenticate, 3)

    authenticated? = authenticate.(db_server, "Bob", "penguin1")

    if !authenticated? do
      IO.puts("Authentication failed")
      finish()
    end

    if !ByMove.have_func?(Users, {:deposit, 3}) do
      IO.puts "Waiting for deposit"
      ByMove.i_need_func({:deposit, 3}, nodes, self())
      ByMove.module_wait_for_func(Users, {:deposit, 3}, nodes, self(), [])
    end

    IO.puts "has func deposit"
    deposit = Function.capture(Users, :deposit, 3)
    new_balance = deposit.(db_server, "Bob", 100)
    IO.puts "Process done"
    IO.puts("New balance: #{new_balance}")
    mark_done()
    finish()
  end

  def server do
    db_server = :global.whereis_name(:database)
    receive do
      {:get_balance, user, from_pid} ->
        balance = Users.get_balance(db_server, user)
        send(from_pid, balance)
      x -> IO.puts("Unknown message: #{inspect(x)}")
    end
    server()
  end

  def main_standard(nodes, db_server) do
    wait_till_start()

    auth_pid = nodes |> Enum.at(0)
    transaction_pid = nodes |> Enum.at(1)

    send(auth_pid, {:authenticate, "Bob", "penguin1", self()})
    authenticated? = receive do
      authenticated? -> authenticated?
    end

    if !authenticated? do
      IO.puts("Authentication failed")
    end

    send(transaction_pid, {:deposit, "Bob", 100, self()})

    new_balance = receive do
      new_balance -> new_balance
    end
    IO.puts("New balance: #{new_balance}")
    mark_done()
  end

  def wait_till_start do
    if :global.whereis_name(:ready) == :undefined do
      wait_till_start()
    end
  end

  def finish() do
    IO.puts "releasing functions"
    ByMove.module_release_functions(Users)
  end

  def mark_done() do
    pid = :global.whereis_name(:ready)
    send(pid, :node2_done)
  end

end

defmove Users do
  def setup(test) do
    Node.start(:"node2@192.168.0.10")
    Node.set_cookie(:mycookie)
    Node.connect(:"database@192.168.0.13")
    if test==:bymove do
      :global.register_name :node2, self()
    else
      :global.register_name :node2, spawn(fn -> Node2.server() end)
    end
  end

  def setup2() do
    node3 = :global.whereis_name(:node3)
    node1 = :global.whereis_name(:node1)
    db_server = :global.whereis_name(:database)
    nodes = [node1, node3]
    {nodes, db_server}
  end

  def get_balance(db_server, user) do
    GenServer.call(db_server, {:get_balance, user})
  end

  def finish do
    ByMove.release_functions()
  end

end
