local c = require("buffertag.config")
local M = {}

-- holds any currently open floating windows displaying buffer tags
local float_wins = {}

function create_tag_float(parent_win)
    local buf = vim.api.nvim_win_get_buf(parent_win)
    local buf_name = vim.api.nvim_buf_get_name(buf)
    buf_name = vim.fn.fnamemodify(buf_name, ":~:.")

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

    local popup_text = buf_name
    -- By default, the popup width is the same as the length of the buffer text we want to show.
    local popup_width = #buf_name

    local window_width = vim.api.nvim_win_get_width(parent_win)
    -- Subtract 5 here to give the window a bit of padding - otherwise it can
    -- look a bit squashed as technically the text fits, but it's right up to
    -- the very edge of the pane and doesn't look great
    local window_width_with_padding = window_width - 5;

  if c.config.limit_width and popup_width > window_width_with_padding then
      popup_width = window_width_with_padding
      -- Take the last X characters of the buf_name, where X is the available width.
      -- e.g. if the name is foo/bar/baz.js, and the width is 6, this will return baz.js
      popup_text = string.sub(popup_text, #buf_name - popup_width + 1, #buf_name)
    end

    if popup_width >= vim.api.nvim_win_get_width(0) or popup_width < 0 then
        -- do not paint buffer tag
        return
    end


    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'delete')
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, {popup_text})
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    local popup_conf = {
        relative = "win",
        anchor = "NE",
        win = parent_win,
        width = popup_width,
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
        {"WinEnter", "CursorHold"},
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
    if c.config.start_enabled then
        M.toggle()
    end
end

return M
