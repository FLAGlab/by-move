import ByMove

defmodule Node2 do
  def main(nodes, db_server) do
    wait_till_start()

    if !ByMove.has_func?(Users, {:authenticate, 3}) do
      ByMove.i_need_func({:authenticate, 3}, nodes, self())
      ByMove.module_wait_for_func(Users, {:authenticate, 3})
    end

    authenticate = Function.capture(Users, :authenticate, 3)

    authenticated? = authenticate.(db_server, "Bob", "penguin1")

    if !authenticated? do
      IO.puts("Authentication failed")
      finish()
    end

    if !ByMove.have_func?(Users, {:deposit, 3}) do
      ByMove.i_need_func({:deposit, 3}, nodes, self())
      ByMove.module_wait_for_func(Users, {:deposit, 3})
    end

    deposit = Function.capture(Users, :deposit, 3)
    new_balance = deposit.(db_server, "Bob", 100)
    IO.puts("New balance: #{new_balance}")
    finish()
  end

  def wait_till_start do
    if :global.whereis_name(:ready) == :undefined do
      wait_till_start()
    end
  end

  def finish() do
    ByMove.module_release_functions(Users)
  end

end

defmove Users do
  def setup() do
    Toolshed.cmd("epmd -daemon")
    Node.start(:"node2@192.168.0.13")
    Node.set_cookie(:mycookie)
    Node.connect(:"database@192.168.0.16")
    :global.register_name :node2, self()
  end

  def setup2() do
    node3 = :global.whereis_name(:node3)
    node1 = :global.whereis_name(:node1)
    db_server = :global.whereis_name(:database)
    nodes = [node3, node1]
    {nodes, db_server}
  end

  def get_balance(db_server, user) do
    GenServer.call(db_server, {:get_balance, user})
  end

  def finish do
    ByMove.release_functions()
  end

  def get_ast do
    @ast
  end

end
