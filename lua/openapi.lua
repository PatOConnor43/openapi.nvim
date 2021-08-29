local _, Job = pcall(require, 'plenary.job')
local yaml = require('openapi.yaml')
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

function M.open_preview()
  local name = vim.call('bufname', vim.api.nvim_get_current_buf())
  local job = Job:new({
    enable_recording = false,
    command = 'redoc-cli',
    args = { 'bundle', name },
  })
  job:after_success(function()
    vim.defer_fn(function()
      vim.fn.system('xdg-open redoc-static.html')
    end, 100)
  end)
  job:start()
end

function M.add_new_path()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, 'ft')
  if ft == 'yaml' then
    return yaml.add_new_path()
  else
    vim.notify(string.format('filetype %s not supported', ft), 'error')
    return
  end
end

function M.add_new_operation()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, 'ft')
  if ft == 'yaml' then
    return yaml.add_new_operation()
  else
    vim.notify(string.format('filetype %s not supported', ft), 'error')
    return
  end
end

function M.get_paths()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, 'ft')
  if ft == 'yaml' then
    return yaml.get_paths()
  else
    vim.notify(string.format('filetype %s not supported', ft), 'error')
    return
  end
end

function M.get_operations(path)
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, 'ft')
  if ft == 'yaml' then
    return yaml.get_operations(path)
  else
    vim.notify(string.format('filetype %s not supported', ft), 'error')
    return
  end
end

function M.test()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, 'ft')
  local parser = vim.treesitter.get_parser(bufnr, ft)
  local tstree = parser:parse()[1]
  local root = tstree:root()
  local paths_query = [[
    (block_mapping_pair key: ((flow_node) @key (eq? @key "paths")) value: (block_node) @value)
  ]]

  local paths = M.get_paths()
  print(get_path_under_cursor())
  print(vim.inspect(M.get_operations(paths['/user/{username}'])))
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
