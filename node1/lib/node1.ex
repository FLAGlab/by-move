import ByMove

defmove Authentication do

  def main() do
    # Aqui quiero autenticar un usuario, revisar el balance y sacar 50 dolares.
    authenticated? = authenticate(:db_server, "john", "password123")

    if !authenticated? do
      IO.puts("Authentication failed")
      exit
    end

    if !ByMove.have_func?(:get_balance, 2) do
      ByMove.i_need_func({:get_balance, 2}, self())
    end

  end

  def authenticate(db_server, user, password) do
    hashed = String.reverse(password)
    GenServer.call(db_server, {:authenticate, user, hashed})
  end
end
