defmodule ByMove do
  defmacro defmove(name, do: block) do
    module_ast = quote do
      defmodule unquote(name) do
        unquote(block)
      end
    end
    quote do
      defmodule unquote(name) do
        @ast unquote(Macro.escape(module_ast))
        unquote(block)
      end
    end
  end

  defmacro send_by_move(dest, {func_name, func_arity}) do
    quote do
      send_by_move(unquote(dest), {unquote(func_name), unquote(func_arity)}, @ast)
    end
  end

  def send_by_move(dest, {func_name, func_arity}, ast) do
    func_def = get_func_def(ast, {func_name, func_arity})
    delete_func_load(ast, {func_name,func_arity})
    send(dest, {:ok, func_def})
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
    new_ast = insert_func(ast, func)
    insert_att(new_ast, insert_ast(new_ast))
    |> Code.compile_quoted
  end

  def delete_func_load(ast, func) do
    new_ast = delete_func(ast, func)
    insert_att(new_ast, insert_ast(new_ast))
    |> Code.compile_quoted
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

  def insert_att([do: {:__block__, meta, args}], att) when is_list(args) do
    #TODO case where module defines only 1 function
    [do: {:__block__, meta, [att] ++ args}]
  end
  def insert_att({name, meta, args}, att) do
    {name, meta, insert_att(args, att)}
  end
  def insert_att([x|xs], att) do
    if is_tuple(x) do
      [x]++insert_att(xs, att)
    else
      [insert_att(x,att)]
    end
  end

  def delete_func({:defmodule, meta, [aliases | [doblock]]}, func) do
    {:defmodule, meta, [aliases | [delete_func(doblock, func)]]}
  end
  def delete_func([do: {name, meta, args}], func) when is_list(args) do
    [do: {name, meta, delete_func(args, func)}]
  end
  def delete_func([x|xs], {func_name, parity}) do
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
end
