defmodule Database do
  use GenServer
  # state will be like
  # %{
  #   "users" => %{1 => %{name: "John", password: "1234", bank_account_id: 1}, 2 => %{name: "Jane", password: "5678", bank_account_id: 2}},
  #   "bank_accounts" => %{1 => %{balance: 1000}, 2 => %{balance: 2000}}
  # }

  def setup do
    Node.start(:"database@192.168.0.13")
    Node.set_cookie(:mycookie)
    {_,pid} = GenServer.start_link(__MODULE__, default_bank_state(), name: Database)
    :global.register_name :database, pid
  end

  def check_state do
    pid = :global.whereis_name(:database)
    balance = GenServer.call(pid, {:get_balance, "Alice"})
    IO.puts "Alice's balance: #{balance}"
    balance = GenServer.call(pid, {:get_balance, "Bob"})
    IO.puts "Bob's balance: #{balance}"
  end

  def start_test do
    start_time = System.monotonic_time(:millisecond)
    :global.register_name(:ready, self())
    wait_till_finish()
    end_time = System.monotonic_time(:millisecond)
    IO.puts("Time taken: #{end_time - start_time}ms")
  end

  def wait_till_finish do
    if :global.whereis_name(:node1_done) == :undefined do
      wait_till_finish()
    end
    if :global.whereis_name(:node2_done) == :undefined do
      wait_till_finish()
    end
    if :global.whereis_name(:node3_done) == :undefined do
      wait_till_finish()
    end
  end


  def default_bank_state() do
    %{
      "users" => %{
        "Alice" => %{name: "Alice", password: "321drowssap", bank_account_id: 1},
        "Bob" => %{name: "Bob", password: "1niugnep", bank_account_id: 2}
      },
      "bank_accounts" => %{
        1 => %{balance: 1000},
        2 => %{balance: 2000}
      }
    }
  end

  @impl true
  def init() do
    default_bank_state = %{
      "users" => %{
        "Alice" => %{name: "Alice", password: "321drowssap", bank_account_id: 1},
        "Bob" => %{name: "Bob", password: "1niugnep", bank_account_id: 2}
      },
      "bank_accounts" => %{
        1 => %{balance: 1000},
        2 => %{balance: 2000}
      }
    }
    {:ok, default_bank_state}
  end

  @impl true
  def handle_call({:authenticate, username, password}, _from, state) do
    user = Map.get(state, "users", %{}) |> Map.get(username)
    if user && user[:password] == password do
      {:reply, true, state}
    else
      {:reply, false, state}
    end
  end

  @impl true
  def handle_call({:get_balance, username}, _from, state) do
    user = Map.get(state, "users", %{}) |> Map.get(username)
    bank_account_id = user[:bank_account_id]
    balance = Map.get(state, "bank_accounts", %{}) |> Map.get(bank_account_id, %{}) |> Map.get(:balance)
    {:reply, balance, state}
  end

  @impl true
  def handle_call({:deposit, username, amount}, _from, state) do
    user = Map.get(state, "users", %{}) |> Map.get(username)
    bank_account_id = user[:bank_account_id]
    balance = Map.get(state, "bank_accounts", %{}) |> Map.get(bank_account_id) |> Map.get(:balance)
    new_balance = balance + amount
    state = Map.put(state, "bank_accounts", Map.put(Map.get(state, "bank_accounts", %{}), bank_account_id, %{balance: new_balance}))
    {:reply, new_balance, state}
  end

  @impl true
  def handle_call({:withdraw, username, amount}, _from, state) do
    user = Map.get(state, "users", %{}) |> Map.get(username)
    bank_account_id = user[:bank_account_id]
    balance = Map.get(state, "bank_accounts", %{}) |> Map.get(bank_account_id) |> Map.get(:balance)
    new_balance = balance - amount
    state = Map.put(state, "bank_accounts", Map.put(Map.get(state, "bank_accounts", %{}), bank_account_id, %{balance: new_balance}))
    {:reply, new_balance, state}
  end
end
