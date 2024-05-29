import ByMove

defmodule Node1 do
  def main_bymove(nodes, db_server, n) do
    wait_till_start()
    auth = Function.capture(Authentication, :authenticate, 3)


    IO.puts "processing passwords"
    1..n
    |> Enum.map(fn x -> "Password#{x}" end)
    |> Enum.map(fn password -> auth.(db_server, "Alice", password) end)
    |> Enum.reduce(0, fn x, acc -> if x do acc + 1 else acc end end)
    |> IO.inspect



    if !ByMove.has_func?(Authentication, {:get_balance, 2}) do
      IO.puts("Waiting for get_balance")
      ByMove.i_need_func({:get_balance, 2}, nodes, self())
      ByMove.module_wait_for_func(Authentication,{:get_balance, 2}, nodes, self(), [])
    end

    IO.puts("has func get_balance")
    get_balance = Function.capture(Authentication, :get_balance, 2)

    IO.puts "Getting balances"
    1..n
    |> Enum.map(fn x -> get_balance.(db_server, "Alice") end)
    |> hd()
    |> IO.inspect

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

  def main_standard(nodes, db_server, n) do
    wait_till_start()

    IO.puts "started"
    users_pid = nodes |> Enum.at(0)
    transaction_pid = nodes |> Enum.at(1)

    IO.puts "processing passwords"
    1..n
    |> Enum.map(fn x -> "password#{x}" end)
    |> Enum.map(fn password -> Authentication.authenticate(db_server, "Alice", password) end)
    |> Enum.reduce(0, fn x, acc -> if x do acc + 1 else acc end end)
    |> IO.inspect

    IO.puts "Getting balance"
    user_list = 1..n |> Enum.map(fn x -> "Alice" end)
    balance = GenServer.call(users_pid, {:multi_get_balance, user_list}, 100000) |> Enum.at(0)
    IO.puts "Balance: #{balance}"

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
    IO.puts "Authenticating"
    pid = :global.whereis_name(:database)
    result = Authentication.authenticate(pid, user, password)
    {:reply, result, state}
  end

  def handle_call({:multi_authenticate, user_list}, from, state) do
    pid = :global.whereis_name(:database)
    user_list
    |> Enum.map(fn {user, password} -> Authentication.authenticate(pid, user, password) end)
    |> fn x -> {:reply, x, state} end.()
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
