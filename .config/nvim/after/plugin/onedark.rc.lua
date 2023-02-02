local status, n = pcall(require('onedark'))
if (not status) then return end


n.setup( {commit_italics=true})
