require('base')
require('maps')
require('plugins')

local has = function(x)
  return vim.fn.has(x) == 1
end


local is_mac = has 'mac'
local is_win = has 'win32'
local is_linux = has 'linux'

if is_mac or is_linux then
  require('macos')
end

if is_win then
  require('window')
end
