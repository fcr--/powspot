local lgi = require'lgi'

local function cut(filename)
    local img = lgi.GdkPixbuf.Pixbuf.new_from_file(filename)
    local w, h = img:get_width(), img:get_height()
    local basename = filename:gsub('%.[^./]*$', '')
    local buf = lgi.GdkPixbuf.Pixbuf.new('RGB', false, 8, 192, 320)
    local i = 1
    for x = 404, 0, -200 do
        for y = 15, 410, 350 do
            img:scale(buf, 0, 0, 192, 320, -x, -y, 1, 1, 'NEAREST')
            local r, e = buf:rotate_simple'COUNTERCLOCKWISE':savev(basename..'-'..i..'.png', 'png', {}, {})
            if not r then error(e.code..": "..e.message) end
            i = i + 1
        end
    end
end

local function readImage(src)
    local img = lgi.GdkPixbuf.Pixbuf.new_from_file(src)
    local w, h = img:get_width(), img:get_height()
    local pixels = img:get_pixels()
    local bytes = {}
    local byte = 0
    for y = 0, 191 do
        for x = 0, 319 do
            local i = 3*(math.floor(x*w/320) + math.floor(y*h/192)*w)
            local r, g, b = pixels:byte(i+1, i+3)
            byte = bit.bor(byte, (r+g+b > 0x180) and bit.lshift(1, 7 - x%8) or 0)
            if x % 8 == 7 then table.insert(bytes, string.char(byte)); byte = 0 end
        end
    end
    return table.concat(bytes)
end

local Chunk = {}
Chunk.__index = Chunk

function Chunk:new(compressed, data)
    return setmetatable({compressed = compressed, data = data}, self)
end

function Chunk:size_in_bits()
    return #self.data * 8 + 1
end

local CompressedState = {}
CompressedState.__index = CompressedState

function CompressedState:new()
    return setmetatable({total_size_in_bits = 0}, self)
end

function CompressedState:cons(chunk)
    local st = CompressedState:new()
    st.total_size_in_bits = self.total_size_in_bits + chunk:size_in_bits()
    st.chunks = {chunk, self.chunks}
    return st
end

function CompressedState:build()
    local reversed_chunks, chunk
    local cursor = self.chunks
    while cursor do
        chunk, cursor = unpack(cursor)
        reversed_chunks = {chunk, reversed_chunks}
    end
    local res = {}
    local current_chunk_res = {}
    local chunk_count = 0
    local flags = 0
    while reversed_chunks do
        if chunk_count == 8 then
            table.insert(res, string.char(flags))
            for _, c in ipairs(current_chunk_res) do table.insert(res, c) end
            current_chunk_res = {}
            chunk_count = 0
            flags = 0
        end
        chunk, reversed_chunks = unpack(reversed_chunks)
        if chunk.compressed then
            flags = bit.bor(flags, bit.lshift(1, chunk_count))
        end
        table.insert(current_chunk_res, chunk.data)
        chunk_count = chunk_count + 1
    end
    if chunk_count > 0 then
        table.insert(res, string.char(flags))
        for _, c in ipairs(current_chunk_res) do table.insert(res, c) end
    end
    return table.concat(res)
end

local function compress(params)
    local rawdata = params[1]
    local best_for_i = CompressedState:new()
    local best_states = {[0] = best_for_i}
    for i = 0, #rawdata-1 do
        if params.verbose and i % 100 == 0 then
            io.write('compressing byte '..i..'\r')
            io.flush()
        end
        local newlen = best_for_i.total_size_in_bits + 17
        local alt
        for j = math.max(0, i-256), i-1 do
            for l = 0, 257 do
                if i + l >= #rawdata then break end
                local to = j + l >= i and rawdata:sub(j+l%(i-j)+1, j+l%(i-j)+1) or rawdata:sub(j+l+1, j+l+1)
                if to ~= rawdata:sub(i+l+1, i+l+1) then break end
                if l >= 3 then
                    alt = best_states[i+l+1]
                    if not alt or newlen < alt.total_size_in_bits then
                        best_states[i+l+1] = best_for_i:cons(Chunk:new(true, string.char(l-2, i-j-1)))
                    end
                end
            end
        end
        newlen = best_for_i.total_size_in_bits + 9
        alt = best_states[i+1]
        if not alt or newlen < alt.total_size_in_bits then
            alt = best_for_i:cons(Chunk:new(false, rawdata:sub(i+1, i+1)))
            best_states[i+1] = alt
        end
        best_for_i = alt
    end
    if params.verbose then print('compressed '..#rawdata..' bytes') end
    return best_states[#rawdata]:build()
end

local function uncompress(bindata)
    local res, wp, i, flags, flags_count = {}, 1, 1, 0, 0
    while i <= #bindata do
        if flags_count == 0 then
            flags, flags_count, i = bindata:byte(i), 8, i + 1
        elseif bit.band(flags, 1) == 0 then
            res[wp], wp = bindata:sub(i, i), wp + 1
            flags, flags_count, i = bit.rshift(flags, 1), flags_count - 1, i + 1
        else
            local len, off = bindata:byte(i, i+1)
            for j = 1, len+3 do
                res[wp], wp = res[wp - off - 1], wp + 1
            end
            flags, flags_count, i = bit.rshift(flags, 1), flags_count - 1, i + 2
        end
    end
    return table.concat(res)
end

local function stringtobits(str)
    local cursor = 0
    return function()
        local i, b = bit.rshift(cursor, 3) + 1, 7 - bit.band(cursor, 7)
        if i > #str then return nil end
        cursor = cursor + 1
        return bit.band(bit.rshift(str:byte(i), b), 1)
    end
end

local function bitstostring(bitstream)
    local idx, byte, bytes = 7, 0, {}
    for b in bitstream do
        if b and b ~= 0 then byte = bit.bor(byte, bit.lshift(1, idx)) end
        idx = idx - 1
        if idx < 0 then
            idx = 7
            table.insert(bytes, string.char(byte))
            byte = 0
        end
    end
    if idx ~= 7 then table.insert(bytes, string.char(byte)) end
    return table.concat(bytes)
end

local function bitstobinary(bitstream)
    local res = {}
    for b in bitstream do table.insert(res, b) end
    return table.concat(res)
end

local function rlencode(bitstream, lenbits)
    local lastbit, count = nil, 0
    local function send()
        coroutine.yield(lastbit)
        count = count - 1
        for i = 1, lenbits do -- little endian
            coroutine.yield(bit.band(count, 1))
            count = bit.rshift(count, 1)
        end
    end
    return coroutine.wrap(function()
        for b in bitstream do
            if (b ~= lastbit or count >= bit.lshift(1, lenbits)) and count > 0 then send() end
            lastbit = b
            count = count + 1
        end
        if count > 0 then send() end
    end)
end

local function rldecode(bitstream, lenbits)
    return coroutine.wrap(function()
        while true do
            local b = bitstream()
            if b == nil then return end
            local count = 0
            for i = 0, lenbits - 1 do
                count = bit.bor(count, bit.lshift(bitstream(), i))
            end
            for i = 0, count do coroutine.yield(b) end
        end
    end)
end

if arg[1] == 'cut' then
    cut(arg[2])
elseif arg[1] == 'buildImage' then
    local ofd = io.open(arg[2], 'w')
    ofd:write(readImage(arg[3]))
    ofd:close()
elseif arg[1] == 'buildCompressedImage' then
    local uncompressed = readImage(arg[3])
    local compressed = compress{uncompressed, verbose=true}
    assert(uncompress(compressed) == uncompressed)
    local ofd = io.open(arg[2], 'w')
    ofd:write(compressed)
    ofd:close()
elseif arg[1] == 'test' then
    local f = stringtobits'x'
    assert(f() == 0); assert(f() == 1); assert(f() == 1); assert(f() == 1)
    assert(f() == 1); assert(f() == 0); assert(f() == 0); assert(f() == 0)
    assert(f() == nil)
    assert('pelota' == bitstostring(stringtobits'pelota'))
    assert('pelota' == bitstostring(rldecode(rlencode(stringtobits'pelota', 2), 2)))
    assert(compress{'hola'} == '\0hola')
    assert(compress{'lalalal'} == '\4la\2\1')
    assert(compress{'lallallal lal lal'} == '\40lal\3\2 \4\3')
    assert('necesito necesitar necesidades' == uncompress(compress{'necesito necesitar necesidades'}))
else
    error'syntax: {cut <srcFilename>|buildImage <destFilename> <srcFilename>}'
end

-- vi: et sw=4
