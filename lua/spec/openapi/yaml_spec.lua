test_module = require('openapi.yaml')
local mock = require('luassert.mock')
local stub = require('luassert.stub')

describe('openapi.yaml', function()
  before_each(function()
    vim.api.nvim_command('edit example/openapi.yaml')
  end)

  it('parses paths from a yaml spec', function()
    local paths = test_module.get_paths()
    local names = {
      '/pet',
      '/pet/findByStatus',
      '/pet/findByTags',
      '/pet/{petId}',
      '/pet/{petId}/uploadImage',
      '/store/inventory',
      '/store/order',
      '/store/order/{orderId}',
      '/user',
      '/user/createWithArray',
      '/user/createWithList',
      '/user/login',
      '/user/logout',
      '/user/{username}',
    }
    for name, node in pairs(paths) do
      assert.is_true(vim.tbl_contains(names, name))
      assert.equals(node:type(), 'block_node')
    end
  end)
  it('parses operations for a path node', function()
    local paths = test_module.get_paths()
    local user_username_node = nil
    for name, node in pairs(paths) do
      -- looking for a specific node
      if name == '/user/{username}' then
        user_username_node = node
      end
    end
    local operations = test_module.get_operations(user_username_node)
    local expected_operations = {
      'get',
      'put',
      'delete',
    }
    for name, node in pairs(operations) do
      assert.is_true(vim.tbl_contains(expected_operations, name))
      assert.equals(node:type(), 'block_node')
    end
  end)
  it('adds a new path via lsp text edit', function()
    local paths = test_module.get_paths()
    local maximum_row = 0
    -- Find the highest row because that corresponds to the last path. Add a new
    -- one after that.
    for _, value in pairs(paths) do
      local row, _, _ = value:end_()
      if row > maximum_row then
        maximum_row = row
      end
    end
    local expected_textedit = {
      newText = '  /placeholder:\n    description: description\n',
      range = {
        start = {
          line = maximum_row + 1,
          character = 0,
        },
        ['end'] = {
          line = maximum_row + 1,
          character = 0,
        },
      },
    }

    local lsp_util_mock = mock(vim.lsp.util, true)
    local vim_api_mock = stub(vim.api, 'nvim_win_set_cursor')

    test_module.add_new_path()

    assert.stub(lsp_util_mock.apply_text_edits).was_called_with(
      { expected_textedit },
      1
    )
    assert.stub(vim_api_mock).was_called_with(0, { maximum_row + 2, 3 })
    mock.revert(lsp_util_mock)
    mock.revert(vim_api_mock)
  end)
  it('add a new operation via lsp text edit', function()
    local paths = test_module.get_paths()
    local user_username_node = nil
    for name, node in pairs(paths) do
      -- looking for a specific node
      if name == '/user/{username}' then
        user_username_node = node
      end
    end
    --
    assert.is_true(user_username_node ~= nil)
    local end_row, _, _ = user_username_node:end_()
    -- move cursor to area covered by user_username path
    vim.api.nvim_win_set_cursor(0, { end_row - 1, 0 })

    -- Indentation is very important here. This can make the test difficult to debug
    -- but the indentation is important to assert for functionality too :shrug:
    local expected_textedit = {
      newText = [[
    post:
      description: description
      operationId: userusernamepost
      responses:
        '200':
          description: success
]],
      range = {
        start = {
          line = end_row + 1,
          character = 0,
        },
        ['end'] = {
          line = end_row + 1,
          character = 0,
        },
      },
    }

    local lsp_util_mock = mock(vim.lsp.util, true)
    local vim_api_mock = stub(vim.api, 'nvim_win_set_cursor')

    test_module.add_new_operation()

    assert.stub(lsp_util_mock.apply_text_edits).was_called_with(
      { expected_textedit },
      1
    )
    assert.stub(vim_api_mock).was_called_with(0, { end_row + 2, 4 })
    mock.revert(lsp_util_mock)
    mock.revert(vim_api_mock)
  end)
end)
