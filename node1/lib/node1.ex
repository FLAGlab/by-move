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
      IO.puts("Waiting for get_balance")
      ByMove.i_need_func({:get_balance, 2}, nodes, self())
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
    IO.puts "Process done"
    IO.puts("New balance: #{new_balance}")
    mark_done()
    finish()
  end

  def server() do
    db_server = :global.whereis_name(:database)
    receive do
      {:authenticate, user, password, from_pid} ->
        authenticated? = Authentication.authenticate(db_server, user, password)
        send(from_pid, authenticated?)
      x -> IO.puts("Unknown message: #{inspect(x)}")
    end
    server()
  end

  def main_standard(nodes, db_server) do
    wait_till_start()

    IO.puts "started"
    users_pid = nodes |> Enum.at(0)
    transaction_pid = nodes |> Enum.at(1)

    auth = Authentication.authenticate(db_server, "Alice", "password123")
    if !auth do
      IO.puts("Authentication failed")
    end

    IO.puts "Getting balance"
    balance = GenServer.call(users_pid, {:get_balance, "Alice"})
    IO.puts "Balance: #{balance}"

    if balance < 50 do
      IO.puts("Insufficient funds")
    end


    new_balance = GenServer.call(transaction_pid, {:withdraw, "Alice", 50})

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
    ByMove.module_release_functions(Authentication)
  end

  def mark_done() do
    pid = :global.whereis_name(:ready)
    send(pid, :node1_done)
  end

end

defmodule AuthServer do
  use GenServer

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:authenticate, user, password}, _from, state) do
    result = Authentication.authenticate(state, user, password)
    {:reply, result, state}
  end
end


defmove Authentication do

  def setup(test) do
    Node.start(:"node1@192.168.0.9")
    Node.set_cookie(:mycookie)
    Node.connect(:"database@192.168.0.13")
    if test==:bymove do
      :global.register_name :node1, self()
    else
      {:ok, pid} = GenServer.start_link(AuthServer, :global.whereis_name(:database))
      :global.register_name :node1, pid
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
