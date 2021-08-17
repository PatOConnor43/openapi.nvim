local _, Job = pcall(require,'plenary.job')
local M = {}

local function get_path_under_cursor()
  local paths = M.get_paths()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
  for path_key, path_node in pairs(paths) do
    local start_row, start_col, end_row, end_col = path_node:range()
    -- I think end_row is always just 1 short
    end_row = end_row + 1
    if start_row <= cursor_row and end_row >= cursor_row then
      return path_key, path_node
    end
  end
end

local function get_children_pairs(node, bufnr)
  local block_mapping = node:child(0)
  local key_node
  local value_node
  local children_pairs = {}

  -- Search for releveant children in pair
  for pair in block_mapping:iter_children() do
    for child in pair:iter_children() do
       if child:type() == 'flow_node' then
         key_node = child
       elseif child:type() == 'block_node' then
         value_node = child
       end
    end
    children_pairs[vim.treesitter.get_node_text(key_node, bufnr)] = value_node
  end
  return children_pairs
end

function M.open_preview()
  local name = vim.call('bufname', vim.api.nvim_get_current_buf())
  local job = Job:new({
      enable_recording = false,
      command = "redoc-cli",
      args = {"bundle", name},
  })
  job:after_success(function()
    vim.defer_fn(function()
      vim.fn.system('xdg-open redoc-static.html')
      end,
      100)
    end)
  job:start()
end

function M.add_new_path()
  local bufnr = vim.api.nvim_get_current_buf()
  local paths = M.get_paths()
  local maximum_row = 0
  -- Find the highest row because that corresponds to the last path. Add a new
  -- one after that.
  for _, value in pairs(paths) do
    local row, _, _ = value:end_()
    if row > maximum_row then
      maximum_row = row
    end
  end
  -- Add a placeholder path.
  vim.fn.appendbufline(bufnr, maximum_row+1, '  /placeholder:')
  -- Move the cursor on top of the 'p' in '/placeholder'.
  vim.api.nvim_win_set_cursor(0, {maximum_row+2, 3})
  -- Visually select 'placeholder' to show what was added.
  vim.cmd('normal! viw')
end

function M.add_new_operation()
  local bufnr = vim.api.nvim_get_current_buf()
  local name, node = get_path_under_cursor()
  local end_row, _, _ = node:end_()
  -- Add a placeholder operation.
  -- TODO: I should find out what operations are already used and then pick one that isn't
  -- maybe come up with some arbitrary priority.
  vim.fn.appendbufline(bufnr, end_row+1, '    placeholder:')
  -- Move the cursor on top of the 'p' in 'placeholder'.
  vim.api.nvim_win_set_cursor(0, {end_row+2, 5})
  -- Visually select 'placeholder' to show what was added.
  vim.cmd('normal! viw')


end

function M.get_paths()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, "ft")
  local parser = vim.treesitter.get_parser(bufnr, ft)
  local tstree = parser:parse()[1]
  local root = tstree:root()
  local paths = {}
  local paths_query = [[
    (block_mapping_pair key: ((flow_node) @key (eq? @key "paths")) value: (block_node) @value)
  ]]


  local query = vim.treesitter.parse_query(ft, paths_query)
  for pattern, match, metadata in query:iter_matches(root, bufnr, 0, vim.api.nvim_buf_line_count(bufnr)) do
    for id, node in pairs(match) do
      -- skip the flow_node that represents the key.
      if node:type() == 'block_node' then
        paths = get_children_pairs(node, bufnr)
      end
    end
  end
  return paths
end

function M.get_operations(path)
  -- TODO: probably could support string path as well
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, "ft")
  local operations_query = [[
    (block_mapping_pair key: ((flow_node) @delete (eq? @delete "delete")) value: (block_node) @deletevalue)
    (block_mapping_pair key: ((flow_node) @get (eq? @get "get")) value: (block_node) @getvalue)
    (block_mapping_pair key: ((flow_node) @head (eq? @head "head")) value: (block_node) @headvalue)
    (block_mapping_pair key: ((flow_node) @options (eq? @options "options")) value: (block_node) @optionsvalue)
    (block_mapping_pair key: ((flow_node) @patch (eq? @patch "patch")) value: (block_node) @patchvalue)
    (block_mapping_pair key: ((flow_node) @post (eq? @post "post")) value: (block_node) @postvalue)
    (block_mapping_pair key: ((flow_node) @put (eq? @put "put")) value: (block_node) @putvalue)
    (block_mapping_pair key: ((flow_node) @connect (eq? @connect "connect")) value: (block_node) @connectvalue)
    (block_mapping_pair key: ((flow_node) @trace (eq? @trace "trace")) value: (block_node) @tracevalue)
  ]]
  local operations = {}

  local query = vim.treesitter.parse_query(ft, operations_query)
  local node_end, _, _ = path:end_()
  for pattern, match, metadata in query:iter_matches(path, bufnr, 0, node_end) do
    -- I know this looks goofy, but since I am putting all the http methods in a
    -- single query I get partial results when iterating through matches.
    -- Basically, there will be a match for `get`, a match for `put`, etc.
    -- The `match` table that they come back in will have batched keys.
    -- So the match for `put` may have [1, 2], but then `get` will have [3, 4].
    -- In order to make sure I use the right indexes with each batch, I am making a
    -- list of the keys and then indexing into those because I can guarantee
    -- that they will always come back in a batch of 2.
    local match_keys = vim.tbl_keys(match)
    if #match_keys == 2 then
      local key = match[match_keys[1]]
      local value = match[match_keys[2]]
      operations[vim.treesitter.get_node_text(key, bufnr)] = value
    end
  end
  return operations
end


function M.test()

  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, "ft")
  local parser = vim.treesitter.get_parser(bufnr, ft)
  local tstree = parser:parse()[1]
  local root = tstree:root()
  local paths_query = [[
    (block_mapping_pair key: ((flow_node) @key (eq? @key "paths")) value: (block_node) @value)
  ]]


  local paths = M.get_paths()
  print(get_path_under_cursor())
  --print(vim.inspect(M.get_operations(paths['/user/{username}'])))
  --local paths = M.get_paths()
  --local last_path
  --local maximum_row = 1
  --local maximum_col = 1
  --for key, value in pairs(paths) do
  --  local row, col, _ = value:end_()
  --  if row > maximum_row then
  --    maximum_row = row
  --    maximum_col = col
  --  end
  --end
  --vim.fn.appendbufline(bufnr, maximum_row+1, '  /placeholder:')
  --vim.api.nvim_win_set_cursor(0, {maximum_row+2, 3})
  ----vim.fn.norm('viw')
  --vim.cmd('normal! viw')
  --vim.api.nvim_buf_set_text(bufnr, maximum_row+1, 0, maximum_row+1, 0, {'','lmao'})
  --print(last_path)
  --print(maximum)
  --local query = vim.treesitter.parse_query(ft, paths_query)
  --for pattern, match, metadata in query:iter_matches(root, bufnr, 0, vim.api.nvim_buf_line_count(bufnr)) do
  --  for id, node in pairs(match) do
  --    -- skip the flow_node that represents the key.
  --    if node:type() == 'block_node' then
  --        print(vim.inspect(get_children_pairs(node, bufnr)))
  --      --local block_mapping = node:child(0)
  --      --for pair in block_mapping:iter_children() do
  --        --print(vim.treesitter.get_node_text(pair:child(0), bufnr))
  --      --end
  --    end
  --  end
  --  --for declared_path, b in value_node:iter_children() do
  --    --  --print(vim.treesitter.get_node_text(a, bufnr))
  --    --  print(declared_path:named_child('key'))
  --    --  --print('hey'..path_key)

  --  --end
  --  --local name = query.captures[id] -- name of the capture in the query
  --  --print("- capture name: " .. name)
  --  --for a, b in node:iter_children() do
  --    --  print(vim.treesitter.get_node_text(a, bufnr))
  --    --  print(node:symbol())
  --  --end
  --  --print_node(string.format("- capture node id(%s)", id), node)
  --end

  --print(paths)

end



return M
