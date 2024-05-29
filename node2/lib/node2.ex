import ByMove

defmodule Node2 do
  def main_bymove(nodes, db_server, n) do
    wait_till_start()

    if !ByMove.has_func?(Users, {:authenticate, 3}) do
      IO.puts "Waiting for authenticate"
      ByMove.i_need_func({:authenticate, 3}, nodes, self())
      ByMove.module_wait_for_func(Users, {:authenticate, 3}, nodes, self(), [])
    end

    IO.puts "has func authenticate"
    authenticate = Function.capture(Users, :authenticate, 3)

    IO.puts "processing passwords"
    1..n
    |> Enum.map(fn x -> "penguin#{x}" end)
    |> Enum.map(fn password -> authenticate.(db_server, "Bob", password) end)
    |> Enum.reduce(0, fn x, acc -> if x do acc + 1 else acc end end)
    |> IO.inspect


    if !ByMove.have_func?(Users, {:deposit, 3}) do
      IO.puts "Waiting for deposit"
      ByMove.i_need_func({:deposit, 3}, nodes, self())
      ByMove.module_wait_for_func(Users, {:deposit, 3}, nodes, self(), [])
    end

    IO.puts "has func deposit"
    deposit = Function.capture(Users, :deposit, 3)

    IO.puts "depositing #{n} times"
    1..n
    |> Enum.map(fn x -> deposit.(db_server, "Bob", 1) end)
    |> List.last()
    |> IO.inspect

    IO.puts "Process done"
    mark_done()
    finish()
  end

  def main_standard(nodes, db_server, n) do
    wait_till_start()

    IO.puts "started"
    auth_pid = nodes |> Enum.at(0)
    transaction_pid = nodes |> Enum.at(1)

    IO.puts "sending authenticate"
    users_list = 1..n |> Enum.map(fn x -> {"Bob", "penguin#{x}"} end)
    auth_list = GenServer.call(auth_pid, {:multi_authenticate, users_list})
                |> Enum.reduce(0, fn x, acc -> if x do acc + 1 else acc end end)
    IO.puts "received authenticate"

    IO.puts "Getting balance"
    users_list = 1..n |> Enum.map(fn x -> "Bob" end)
    new_balance = GenServer.call(transaction_pid, {:multi_deposit, users_list, 1})
                  |> List.last()
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

defmodule UserServer do
  use GenServer

  @impl true
  def init(state) do
    {:ok, state}
  end
  @impl true
  def handle_call({:get_balance, user}, _from, state) do
    pid = :global.whereis_name(:database)
    balance = Users.get_balance(pid, user)
    {:reply, balance, state}
  end

  def handle_call({:multi_get_balance, user_list}, _from, state) do
    pid = :global.whereis_name(:database)
    user_list
    |> Enum.map(fn user -> Users.get_balance(pid, user) end)
    |> fn balances -> {:reply, balances, state} end.()
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
      {:ok, pid} = GenServer.start_link(UserServer, :global.whereis_name(:database))
      :global.register_name :node2, pid
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
