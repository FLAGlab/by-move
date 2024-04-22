defmodule Database do
  use GenServer
  # state will be like
  # %{
  #   "users" => %{1 => %{name: "John", password: "1234", bank_account_id: 1}, 2 => %{name: "Jane", password: "5678", bank_account_id: 2}},
  #   "bank_accounts" => %{1 => %{balance: 1000}, 2 => %{balance: 2000}}
  # }

  @impl true
  def init() do
    default_bank_state = %{
      "users" => %{
        1 => %{name: "John", password: "1234", bank_account_id: 1},
        2 => %{name: "Jane", password: "5678", bank_account_id: 2}
      },
      "bank_accounts" => %{
        1 => %{balance: 1000},
        2 => %{balance: 2000}
      }
    }
    {:ok, default_bank_state}
  end

  @impl true
  def handle_call({:authenticate, user, password}, _from, state) do
    user = Map.get(state, "users", %{}) |> Map.get(user)
    if user && user[:password] == password do
      {:reply, :ok, state}
    else
      {:reply, :error, state}
    end
  end

  @impl true
  def handle_call({:get_balance, user}, _from, state) do
    user = Map.get(state, "users", %{}) |> Map.get(user)
    bank_account_id = user[:bank_account_id]
    balance = Map.get(state, "bank_accounts", %{}) |> Map.get(bank_account_id) |> Map.get(:balance)
    {:reply, balance, state}
  end

  @impl true
  def handle_call({:deposit, user, amount}, _from, state) do
    user = Map.get(state, "users", %{}) |> Map.get(user)
    bank_account_id = user[:bank_account_id]
    balance = Map.get(state, "bank_accounts", %{}) |> Map.get(bank_account_id) |> Map.get(:balance)
    new_balance = balance + amount
    state = Map.put(state, "bank_accounts", Map.put(Map.get(state, "bank_accounts", %{}), bank_account_id, %{balance: new_balance}))
    {:reply, new_balance, state}
  end

  @impl true
  def handle_call({:withdraw, user, amount}, _from, state) do
    user = Map.get(state, "users", %{}) |> Map.get(user)
    bank_account_id = user[:bank_account_id]
    balance = Map.get(state, "bank_accounts", %{}) |> Map.get(bank_account_id) |> Map.get(:balance)
    new_balance = balance - amount
    state = Map.put(state, "bank_accounts", Map.put(Map.get(state, "bank_accounts", %{}), bank_account_id, %{balance: new_balance}))
    {:reply, new_balance, state}
  end


  # @impl true
  # def handle_call({:transaction, user1, user2, amount}, _from, state) do
  #   user1 = Map.get(state, "users", %{}) |> Map.get(user1)
  #   user2 = Map.get(state, "users", %{}) |> Map.get(user2)
  #   bank_account_id1 = user1[:bank_account_id]
  #   bank_account_id2 = user2[:bank_account_id]
  #   balance1 = Map.get(state, "bank_accounts", %{}) |> Map.get(bank_account_id1) |> Map.get(:balance)
  #   balance2 = Map.get(state, "bank_accounts", %{}) |> Map.get(bank_account_id2) |> Map.get(:balance)
  #   new_balance1 = balance1 - amount
  #   new_balance2 = balance2 + amount
  #   state = Map.put(state, "bank_accounts", Map.put(Map.get(state, "bank_accounts", %{}), bank_account_id1, %{balance: new_balance1}))
  #   state = Map.put(state, "bank_accounts", Map.put(Map.get(state, "bank_accounts", %{}), bank_account_id2, %{balance: new_balance2}))
  #   {:reply, {new_balance1, new_balance2}, state}
  # end
end
