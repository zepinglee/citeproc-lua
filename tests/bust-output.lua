local s = require 'say'
local pretty = require 'pl.pretty'
local io = io
local type = type
local string_format = string.format
local string_gsub = string.gsub
local io_write = io.write
local io_flush = io.flush
local pairs = pairs

local colors

if package.config:sub(1,1) == '\\' and not os.getenv("ANSICON") then
  -- Disable colors on Windows.
  colors = setmetatable({}, {__index = function () return function (s) return s end end})
else
  colors = require 'term.colors'
end

return function (options)
  local busted = require 'busted'
  local handler = require 'busted.outputHandlers.base'()

  handler.category_count = {}
  handler.test_count = 0
  handler.colored = true

  local successDot = colors.green('●')
  local failureDot = colors.red('◼')
  local errorDot   = colors.magenta('✱')
  local pendingDot = colors.yellow('◌')

  local function colored(str, status)
    local color = nil
    if status == "success" then
      color = colors.green
    elseif status == "failure" then
      color = colors.red
    elseif status == "error" then
      color = colors.magenta
    elseif status == "pending" then
      color = colors.yellow
    end
    if color and handler.colored then
      return color(str)
    else
      return str
    end
  end

  local function colored_dot(status)
    local dot = ""
    if status == "success" then
      dot = '●'
    elseif status == "failure" then
      dot = '◼'
    elseif status == "error" then
      dot   = '✱'
    elseif status == "pending" then
      dot = '◌'
    end
    return colored(dot, status)
  end

  local pendingDescription = function (pending)
    local name = pending.name

    local string = colors.yellow(s('output.pending')) .. ' → ' ..
      colors.cyan(name)

    if type(pending.message) == 'string' then
      string = string .. '\n' .. pending.message
    elseif pending.message ~= nil then
      string = string .. '\n' .. pretty.write(pending.message)
    end

    return string
  end

  local failureMessage = function (failure)
    local string = failure.randomseed and ('Random seed: ' .. failure.randomseed .. '\n') or ''
    if type(failure.message) == 'string' then
      local message = string.gsub(failure.message, "^.-\n", "")
      string = string .. message
    elseif failure.message == nil then
      string = string .. 'Nil error'
    else
      string = string .. pretty.write(failure.message)
    end

    return string
  end

  local failureDescription = function (failure, isError)
    local string = colors.red(s('output.failure')) .. ' → '
    if isError then
      string = colors.magenta(s('output.error')) .. ' → '
    end

    string = string .. colors.cyan(failure.name) .. '\n' ..
      colors.bright(failureMessage(failure))

    if options.verbose and failure.trace and failure.trace.traceback then
      string = string .. '\n' .. failure.trace.traceback
    end

    return string
  end

  handler.testEnd = function (element, parent, status, debug)

    handler.test_count = handler.test_count + 1

    if not options.deferPrint then
      local string = colored_dot(status)

      io_write(string)
      io_flush()
    end

    local category = string.match(element.name, "^[^_]+")
    if not handler.category_count[category] then
      handler.category_count[category] = {
        success = 0,
        failure = 0,
        error = 0,
        pending = 0,
      }
    end

    if status == "success" then
      handler.category_count[category].success = handler.category_count[category].success + 1
    else
      if status == 'failure' then
        handler.category_count[category].failure = handler.category_count[category].failure + 1
      elseif status == 'error' then
        handler.category_count[category].error = handler.category_count[category].error + 1
      elseif status == 'pending' then
        handler.category_count[category].pending = handler.category_count[category].pending + 1
      end
    end

    return nil, true
  end

  local function get_failures_log()
    local res = ""
    for i, pending in pairs(handler.pendings) do
      res = res .. '\n'
      res = res .. pendingDescription(pending)..'\n'
    end

    for i, err in pairs(handler.failures) do
      res = res .. '\n'
      res = res .. failureDescription(err)..'\n'
    end

    for i, err in pairs(handler.errors) do
      res = res .. '\n'
      res = res .. failureDescription(err, true)..'\n'
    end
    return res
  end

  local function get_status_log()
    local res = string.format("%-14s%8s%8s%8s%8s\n", "category",
      "success", "failure", "error", "pending")

    if not handler.categories then
      handler.categories = {}
      for category, _ in pairs(handler.category_count) do
        table.insert(handler.categories, category)
      end
      table.sort(handler.categories)
    end

    if #handler.categories > 1 then
      res = res .. "-------------- ------- ------- ------- -------\n"
      for _, category in ipairs(handler.categories) do
        local category_count = handler.category_count[category]
        local line = string.format("%-14s", category)

        local str
        str = string.format("%8d", category_count.success)
        if category_count.success > 0 then
          str = colors.green(str)
        end
        line = line .. str

        str = string.format("%8d", category_count.failure)
        if category_count.failure > 0 then
          str = colors.red(str)
        end
        line = line .. str

        str = string.format("%8d", category_count.error)
        if category_count.error > 0 then
          str = colors.magenta(str)
        end
        line = line .. str

        str = string.format("%8d", category_count.pending)
        if category_count.pending > 0 then
          str = colors.yellow(str)
        end
        line = line .. str

        res = res .. line ..  "\n"
      end
    end

    local successes = handler.successesCount
    local pendings = handler.pendingsCount
    local failures = handler.failuresCount
    local errors = handler.errorsCount

    res = res .. "-------------- ------- ------- ------- -------\n"
    local line = string.format("%-14s", "(all)") ..
      colors.green(string.format("%8d", successes)) ..
      colors.red(string.format("%8d", failures)) ..
      colors.magenta(string.format("%8d", errors)) ..
      colors.yellow(string.format("%8d", pendings))

    res = res .. line .. "\n"

    return res
  end

  handler.suiteStart = function (suite, count, total)
    local runString = (total > 1 and '\nRepeating all tests (run %u of %u) . . .\n\n' or '')
    io_write(string_format(runString, count, total))
    io_flush()

    return nil, true
  end

  handler.suiteEnd = function ()

    io_write(get_failures_log())
    io_write("\n")
    io_write(get_status_log())

    local sec = handler.getDuration()
    local formattedTime = string_gsub(string_format('%.6f', sec), '([0-9])0+$', '%1')
    io_write(colors.bright(formattedTime) .. ' ' .. s('output.seconds') .. "\n")

    if handler.test_count > 800 then
      colors = setmetatable({}, {__index = function () return function (s) return s end end})
      local file = io.open("tests/citeproc-test.log", "w")
      file:write(get_status_log())
      file:write(get_failures_log())
      file:close()
    end

    return nil, true
  end

  handler.error = function (element, parent, message, debug)
    io_write(errorDot)
    io_flush()

    return nil, true
  end

  busted.subscribe({ 'test', 'end' }, handler.testEnd, { predicate = handler.cancelOnPending })
  busted.subscribe({ 'suite', 'start' }, handler.suiteStart)
  busted.subscribe({ 'suite', 'end' }, handler.suiteEnd)
  busted.subscribe({ 'error', 'file' }, handler.error)
  busted.subscribe({ 'failure', 'file' }, handler.error)
  busted.subscribe({ 'error', 'describe' }, handler.error)
  busted.subscribe({ 'failure', 'describe' }, handler.error)

  return handler
end
