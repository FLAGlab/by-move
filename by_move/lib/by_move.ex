defmodule ByMove do
  defmacro defmove(name, do: block) do
    get_ast_function_ast = quote do
      def get_ast do
        @ast
      end
    end
    module_ast = quote do
      defmodule unquote(name) do
        unquote(block)
      end
    end
    module_ast = insert_func(module_ast, get_ast_function_ast)
    quote do
      defmodule unquote(name) do
        @ast unquote(Macro.escape(module_ast))
        unquote(block)
        def get_ast do
          @ast
        end
      end
    end
  end

  def send_by_move(dest, {func_name, func_arity}, ast) do
    func_def = get_func_def(ast, {func_name, func_arity})
    IO.puts("Sending func:")
    # IO.inspect func_def
    IO.puts "AST:------------------------------------------"
    # IO.inspect ast
    new_ast = delete_func_load(ast, {func_name,func_arity})
    send(dest, {:func_def, func_def})
    new_ast
  end

  defmacro send_by_move(dest, {func_name, func_arity}) do
    quote do
      ByMove.send_by_move(unquote(dest), {unquote(func_name), unquote(func_arity)}, @ast)
    end
  end

  defmacro recieve_by_move(do: ast) do
    nil
  end

  def get_file_ast(file_path) do
    file = File.read!(file_path)
    {:ok, ast} = Code.string_to_quoted(file)
    ast
  end

  def insert_ast(module_ast) do
    quote do
      @ast unquote(Macro.escape(module_ast))
    end
  end

  def insert_func_load(ast, func) do
    #get file, insert function into module ast, reload module.
    IO.puts "Inserting func:"
    # IO.inspect func
    new_ast = insert_func(ast, func)
    ast_updated = insert_ast(new_ast, insert_ast(new_ast))
    IO.puts "To be compiled:"
    # IO.inspect ast_updated
    Code.compile_quoted(ast_updated, "./error.txt")
    ast_updated
  end

  def delete_func_load(ast, func) do
    new_ast = delete_func(ast, func)
    ast_updated = insert_ast(new_ast, insert_ast(new_ast))
    Code.compile_quoted(ast_updated)
    ast_updated
  end

  def get_func_def_from_file(file_path, func) do
    file = File.read!(file_path)
    {:ok, ast} = Code.string_to_quoted(file)
    get_func_def(ast, func)
  end


  def insert_func([do: {name, meta, args}], func) when is_list(args) do
    [do: {name, meta, args ++ [func]}]
  end
  def insert_func({name, meta, args}, func) do
    {name, meta, insert_func(args, func)}
  end
  def insert_func([x|xs], func) do
    if is_tuple(x) do
      [x]++insert_func(xs, func)
    else
      [insert_func(x,func)]
    end
  end

  def insert_ast([do: {:__block__, meta, args}], att) when is_list(args) do
    #TODO case where module defines only 1 function
    [do: {:__block__, meta, [att] ++ args}]
  end
  def insert_ast({name, meta, args}, att) do
    {name, meta, insert_ast(args, att)}
  end
  def insert_ast([x|xs], att) do
    if is_tuple(x) do
      [x]++insert_ast(xs, att)
    else
      [insert_ast(x,att)]
    end
  end

  def delete_func({:defmodule, meta, [aliases | [doblock]]}, func) do
    {:defmodule, meta, [aliases | [delete_func(doblock, func)]]}
  end
  def delete_func([do: {name, meta, args}], func) when is_list(args) do
    [do: {name, meta, delete_func(args, func)}]
  end
  def delete_func([x|xs], {func_name, parity}) do
    IO.puts "Deleting func: ------------------------------"
    # IO.inspect x
    if pattern_match_function(x, {func_name, parity}) do
      xs
    else
      [x] ++ delete_func(xs, {func_name, parity})
    end
  end


  def get_func_def(ast, {func_name, arity}) do
    result = Macro.path(ast, &(pattern_match_function(&1, {func_name,arity})))
    |> hd
  end

  defp pattern_match_function({:def, _, [{func_name1, _, _} | _]}, {func_name2, arity}) when func_name1 == func_name2, do: true
  defp pattern_match_function(_, _), do: false


  defmacro have_func?({func_name, arity}) do
    quote do
      ByMove.have_func?(@ast, {unquote(func_name), unquote(arity)})
    end
  end

  def have_func?(ast, {func_name, arity}) do
    result = Macro.path(ast, &(pattern_match_function(&1, {func_name,arity})))
    if is_nil(result) do
      false
    else
      true
    end
  end

  def i_need_func({func_name, arity}, destinations, origin) do
    Enum.each(destinations, fn dest -> send(dest, {:need_func, {func_name, arity}, origin}) end)
  end


  defmacro wait_for_func(func, destinations, self, protected \\ []) do
    quote do
      ByMove.wait_for_func(@ast, unquote(func), unquote(destinations), unquote(self), unquote(protected))
    end
  end
  def wait_for_func(ast, {func_name, arity}, destinations, self, protected) do
    IO.puts "waiting........."
    receive do
      {:func_def, func_def} ->  IO.puts "Received func def:"
                                # IO.inspect func_def
                                ByMove.insert_func_load(ast, func_def)
      {:need_func, {func_name, arity}, origin} ->
        new_ast = if !({func_name, arity} in protected)  && ByMove.have_func?(ast, {func_name, arity}) do
          ByMove.send_by_move(origin, {func_name, arity}, ast)
        else
          ast
        end
        # i_need_func({func_name, arity}, destinations, self)
        wait_for_func(new_ast, {func_name, arity}, destinations, self, protected)
      _ -> wait_for_func(ast, {func_name, arity},destinations, self, protected)
    end
  end

  defmacro release_functions() do
    quote do
      ByMove.release_functions(@ast)
    end
  end

  def release_functions(ast) do
    receive do
      {:need_func, {func_name, arity}, origin} ->
        new_ast = if ByMove.have_func?(ast, {func_name, arity}) do
          ByMove.send_by_move(origin, {func_name, arity}, ast)
        else
          ast
        end
        release_functions(new_ast)
      _ -> release_functions(ast)
    end
  end

  def module_release_functions(module) do
    get_ast = Function.capture(module, :get_ast, 0)
    ast = get_ast.()
    release_functions(ast)
  end

  def has_func?(module, {func_name, arity}) do
    get_ast = Function.capture(module, :get_ast, 0)
    ast = get_ast.()
    result = Macro.path(ast, &(pattern_match_function(&1, {func_name,arity})))
    if is_nil(result) do
      false
    else
      true
    end
  end

  def module_wait_for_func(module, {func_name, arity}, destinations, origin, protected \\ []) do
    get_ast = Function.capture(module, :get_ast, 0)
    ast = get_ast.()
    wait_for_func(ast, {func_name, arity}, destinations, origin, protected)
  end

end
