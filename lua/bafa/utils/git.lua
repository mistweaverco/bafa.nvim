---@module 'bafa.utils.git'
local M = {}

----@type string The URL of the Plenary.nvim Git repository.
M.plenary_repo_url = "https://github.com/nvim-lua/plenary.nvim"

---Clones a Git repository to the specified destination path.
---@param repo_url string The URL of the Git repository to clone.
---@param destination_path string The local path where the repository should be cloned.
---@return boolean|nil, string[]|nil Returns true and the output if successful, false otherwise (if on_complete is nil).
M.clone_sync = function(repo_url, destination_path)
  local cmd = { "git", "clone", repo_url, destination_path }
  local result = vim.fn.systemlist(cmd)
  local exit_code = vim.v.shell_error
  return exit_code == 0, result
end

---Clones a Git repository to the specified destination path.
---@param repo_url string The URL of the Git repository to clone.
---@param destination_path string The local path where the repository should be cloned.
---@param on_complete function|nil A callback function that is called when the clone operation is complete
---@return nil
M.clone = function(repo_url, destination_path, on_complete)
  local cmd = { "git", "clone", repo_url, destination_path }
  vim.fn.jobstart(cmd, {
    on_exit = function(_, exit_code, _)
      if on_complete then on_complete(exit_code == 0) end
    end,
  })
end

return M
