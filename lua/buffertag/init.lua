local c = require("buffertag.config")
local M = {}

-- holds any currently open floating windows displaying buffer tags
local float_wins = {}

function relative_buffer_name(buf_name)
    local cwd = vim.fn.getcwd() .. "/"
    local rel_name = vim.fn.substitute(buf_name, cwd, "", "")
    return rel_name
end

function create_tag_float(parent_win)
    local buf = vim.api.nvim_win_get_buf(parent_win)
    local buf_name = vim.api.nvim_buf_get_name(buf)
    buf_name = relative_buffer_name(buf_name)

    if vim.api.nvim_buf_get_option(buf, "modified") then
        buf_name = "[+] " .. buf_name
    end

    -- couldn't determine a buffer name, for whatever reason, just return and dont
    -- tag the buffer.
    if #buf_name <= 0 then
        return
    end

    -- only consider normal buffers with files loaded into them.
    if vim.api.nvim_buf_get_option(buf, "buftype") ~= "" then
        return
    end

    local buf = vim.api.nvim_create_buf(false, true)
    if buf == 0 then
        vim.api.nvim_err_writeln("details_popup: could not create details buffer")
        return nil
    end
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'delete')
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, {buf_name})
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    
    local popup_conf = {
        relative = "win",
        anchor = "NE",
        win = parent_win,
        width = #buf_name,
        height = 1,
        focusable = false,
        zindex = 1,
        style = "minimal",
        border = c.config.border,
        row = 0,
        col = vim.api.nvim_win_get_width(parent_win),
    }
    local float_win = vim.api.nvim_open_win(buf, false, popup_conf)
    table.insert(float_wins, float_win)
end

function M.display_buffertags()
    local cur_win = vim.api.nvim_get_current_win()
    local wins_to_tag = {}
    M.remove_buffertags()
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if w ~= cur_win then
            table.insert(wins_to_tag, w)
        end
    end
    for _, w in ipairs(wins_to_tag) do
        create_tag_float(w)
    end
end

function M.remove_buffertags()
    for _, float in ipairs(float_wins) do
        if vim.api.nvim_win_is_valid(float) then
            vim.api.nvim_win_close(float, true)
        end
    end
    float_wins = {}
end

local au_id = nil

local enabled = false

function M.enable()
    au_id = vim.api.nvim_create_autocmd(
        {"WinEnter"},
        {callback = M.display_buffertags}
    )
    enabled = true
    -- run it so an initial window move isn't necessary
    M.display_buffertags()
end

function M.disable()
    if au_id ~= nil then
        vim.api.nvim_del_autocmd(au_id)
    end
    enabled = false
    M.remove_buffertags()
end

function M.toggle()
    if enabled then
        M.disable()
    else
        M.enable()
    end
end

function M.setup(config)
    if config ~= nil then
        for k, v in pairs(config) do
            c.config[k] = v
        end
    end

    vim.api.nvim_create_user_command("BuffertagToggle", M.toggle, {
        desc = "Toggle the Buffertag feature on and off."
    })

    -- toggle it on.
    M.toggle()
end

return M
