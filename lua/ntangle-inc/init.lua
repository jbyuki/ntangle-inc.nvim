-- Generated using ntangle.nvim
local M = {}
local HL = {}

local LINE_TYPE = {
	ROOT_SECTION = 1,
	SECTION = 2,
	REFERENCE = 3,
	META_SECTION = 5,
	TEXT = 4,

	FILLER = 6,

}

local HL_ELEM_TYPE = {
	SECTION_PART = 1,

	REFERENCE = 2,

	TEXT = 3,

	META_SECTION = 4,

	FILLER = 5,

}

M.HL_ELEM_TYPE = HL_ELEM_TYPE


M.ll_to_hl = {}
local ll_to_hl = M.ll_to_hl
setmetatable(ll_to_hl, {__mode = "k"})

local hl_path_to_hl = {}
local hl_to_hl_path = {}
setmetatable(hl_path_to_hl, { __mode = "v" })
setmetatable(hl_to_hl_path, { __mode = "k" })
M.hl_to_hl_path = hl_to_hl_path

M.ntangle_folder = ".ntangle"
local LL = {}

local root_callbacks = {}

local change_callbacks = {}

M.buf_to_uri = {}
M.uri_to_buf = {}

M.root_to_mirror_buf = {}
local root_to_mirror_buf = M.root_to_mirror_buf
M.mirror_buf_to_root = {}
local mirror_buf_to_root = M.mirror_buf_to_root

local num_root = {}

M.buf_to_hl = {}

M.buf_filetype = {}
local buf_filetype  = M.buf_filetype

M.lls = {}
local lls = M.lls

local trim1

function HL:getlines(hl_elem, lnum, lines, prefix)
	local prefix = prefix or ""
	while hl_elem and lnum > 0 do
		if hl_elem.type == HL_ELEM_TYPE.SECTION_PART then
			return lnum

		elseif hl_elem.type == HL_ELEM_TYPE.REFERENCE then
			local section = self.sections[hl_elem.name]
			if section then
				local part = section.parts.head
				while part and lnum > 0 do
					lnum = self:getlines(part.lines.head, lnum, lines, prefix .. hl_elem.prefix)
					part = part.next
				end
			end

		elseif hl_elem.type == HL_ELEM_TYPE.TEXT then
			table.insert(lines, prefix .. hl_elem.ll_elem.str)
			lnum = lnum - 1

		end
		hl_elem = hl_elem.next
	end
	return lnum
end

function HL:getlines_next(hl_elem, lines, prefix)
	local prefix = prefix or ""

	while hl_elem do
		if hl_elem.type == HL_ELEM_TYPE.SECTION_PART then
			break
		elseif hl_elem.type == HL_ELEM_TYPE.FILLER then
			break
		elseif hl_elem.type == HL_ELEM_TYPE.REFERENCE then
			local section = self.sections[hl_elem.name]
			if section then
				local part = section.parts.head
				while part  do
					self:getlines_next(part.lines.head, lines, prefix .. hl_elem.prefix)
					part = part.next
				end
			end

		elseif hl_elem.type == HL_ELEM_TYPE.TEXT then
			table.insert(lines, prefix .. hl_elem.ll_elem.str)

		end
		hl_elem = hl_elem.next
	end
end

function HL:getlines_all(hl_elem)
	local lines = {}
	local prefix = ""
	if hl_elem.type == HL_ELEM_TYPE.SECTION_PART then
		self:getlines_next(hl_elem.lines.head, lines)
	elseif hl_elem.type == HL_ELEM_TYPE.REFERENCE then
		local section = self.sections[hl_elem.name]
		if section then
			local part = section.parts.head
			while part  do
				self:getlines_next(part.lines.head, lines, prefix .. hl_elem.prefix)
				part = part.next
			end
		end

	elseif hl_elem.type == HL_ELEM_TYPE.TEXT then
		local prefix = ""
		table.insert(lines, prefix .. hl_elem.ll_elem.str)

	else
		assert(false)
	end
	return lines
end


function HL:new()
	local hl = {}
	hl.sections = {}

	-- set weak keys when indexing with table for fallback sections
	setmetatable(hl.sections, { __mode = "k" })

	return setmetatable(hl, { __index = self })
end

function M.insert_hl(source, ll, ll_elem)
	local line = ll_elem.str
	local line_type = M.parse_line(line)

	local hl
	if ll_elem == ll.head then
		hl = ll_to_hl[ll]

		if line_type == LINE_TYPE.META_SECTION then
			local name = trim1(line:sub(4))

			if hl then
				local it = ll.head.next
				while it do
					M.remove_hl(source, ll, it)
					it = it.next
				end
			end

			local hl_path = M.get_hl_path(source, name)
			hl = M.get_hl(hl_path)

			local hl_elem = {
				type = HL_ELEM_TYPE.META_SECTION,
				name = name
			}

			if not ll_elem.hl_elem then
				hl_elem.ll_elem = ll_elem
				ll_elem.hl_elem = hl_elem

			end

			local it = ll.head.next
			ll_to_hl[ll] = hl
			while it do
				M.insert_hl(source, ll, it)
				it = it.next
			end

		elseif ll.head.next and ll.head.next.hl_elem.type == HL_ELEM_TYPE.META_SECTION then
			if hl then
				local it = ll.head.next
				while it do
					M.remove_hl(source, ll, it)
					it = it.next
				end
			end

			hl = HL:new()

			local it = ll.head.next
			ll_to_hl[ll] = hl
			while it do
				M.insert_hl(source, ll, it)
				it = it.next
			end

		elseif not hl then
			hl = HL:new()

			M.hl_to_hl_path[hl] = M.get_hl_path(source, ".")
			local it = ll.head.next
			ll_to_hl[ll] = hl
			while it do
				M.insert_hl(source, ll, it)
				it = it.next
			end

		end

	else
		hl = ll_to_hl[ll]
	end

	if line_type == LINE_TYPE.TEXT then
		return hl:insert_text(ll, ll_elem)
	elseif line_type == LINE_TYPE.REFERENCE then
		return hl:insert_reference(ll, ll_elem)
	elseif line_type == LINE_TYPE.SECTION then
		return hl:insert_section(ll_elem)
	elseif line_type == LINE_TYPE.ROOT_SECTION then
		return hl:insert_root_section(ll_elem)
	elseif line_type == LINE_TYPE.META_SECTION then
		return hl:insert_meta_section(ll, ll_elem)
	elseif line_type == LINE_TYPE.FILLER then
		return hl:insert_filler(ll, ll_elem)

	else
		assert(false, "Invalid line type")
	end
end

function M.parse_line(line)
	if not line then
		return LINE_TYPE.FILLER
	end

	local _, _, prefix = line:find("^%s*([:;]*)")
	local line_type = nil
	if prefix == "" then
		line_type = LINE_TYPE.TEXT
	elseif prefix == ";" then
		line_type = LINE_TYPE.REFERENCE
	elseif prefix == ";;" then
		line_type = LINE_TYPE.SECTION
	elseif prefix == "::" then
		line_type = LINE_TYPE.ROOT_SECTION
	elseif prefix == ";;;" then
		line_type = LINE_TYPE.META_SECTION
	else
		line_type = LINE_TYPE.TEXT
	end
	return line_type
end

function HL:insert_root_section(ll_elem)
	local line = ll_elem.str
	local name = trim1(line:sub(3))

	local hl_elem = {
		type = HL_ELEM_TYPE.SECTION_PART,
		name = name,
		lines = LL:new(),
		size = 0,

	}

	hl_elem.ll_elem = ll_elem
	ll_elem.hl_elem = hl_elem

	local section = self.sections[name]
	if not section then
		 section = {
			name = name,
			parts = LL:new(),
			size = 0,

			refs = {},

		}
		self.sections[name] = section
	end

	section.root = true

	for _, cb in ipairs(root_callbacks) do
		cb(self, section, true)
	end

	section.parts:push_back(hl_elem)
	hl_elem.section = section

	local toremove = {}

	local elem = ll_elem.next
	while elem do
		if elem.hl_elem then
			if elem.hl_elem.type == HL_ELEM_TYPE.SECTION_PART then
				break
			else
				table.insert(toremove, elem.hl_elem)
			end
		end
		elem = elem.next
	end

	local elem_sizes = {}
	local remove_total = 0
	for _, elem in ipairs(toremove) do
		local elem_size = self:get_size(elem)
		table.insert(elem_sizes, elem_size)
		remove_total = remove_total + elem_size
	end

	if remove_total > 0 then
		local nt_infos = self:get_nt_from_hl_elem(toremove[1]) 

		for _, cb in ipairs(change_callbacks) do
			cb(nt_infos, 0, remove_total, toremove[1])
		end
	end


	for i, elem_size in ipairs(elem_sizes) do
		self:update_size_rec(toremove[i].part, -elem_size)
	end

	for _, elem in ipairs(toremove) do
		elem.part.lines:remove(elem)
		elem.part = nil
	end

	for _, elem in ipairs(toremove) do
		elem.part = hl_elem
		elem.part.lines:push_back(elem)
	end

	for i, elem_size in ipairs(elem_sizes) do
		self:update_size_rec(toremove[i].part, elem_size)
		if elem_size > 0 then
			local nt_infos = self:get_nt_from_hl_elem(toremove[i]) 
			for _, cb in ipairs(change_callbacks) do
				cb(nt_infos, elem_size, 0, toremove[i])
			end
		end

	end


	return hl_elem
end

function trim1(s)
   return s:gsub("^%s*(.-)%s*$", "%1")
end

function HL:get_size(hl_elem)
	if hl_elem.type == HL_ELEM_TYPE.TEXT then
		return 1
	elseif hl_elem.type == HL_ELEM_TYPE.REFERENCE then
		if self:is_recursive(hl_elem) then
			return 0
		else
			local section = self.sections[hl_elem.name]
			if section then
				return section.size
			else
				return 0
			end
		end

	elseif hl_elem.type == HL_ELEM_TYPE.FILLER then
		return 0

	else
		assert(false, "hl_elem should not be anything except text and reference")
	end
end

function HL:is_recursive(hl_elem)
	local name = hl_elem.name
	local open = {}
	local close = {}

	local hl_elem_section = hl_elem.part.section
	table.insert(open, hl_elem_section)

	while #open > 0 do
		local section = open[#open]
		table.remove(open)

		for _, ref in ipairs(section.refs) do
			local ref_section = ref.part.section
			if ref_section == hl_elem_section then
				return true
			end

			if not close[ref_section] then
				table.insert(open, ref_section)
				close[ref_section] = true
			end
		end
	end

	return false
end

function HL:update_size_rec(section_part, delta_size, blacklisted)
	local section = section_part.section
	blacklisted = blacklisted or {} 
	if blacklisted[section] then
		return
	end

	section_part.size = section_part.size + delta_size
	section.size = section.size + delta_size

	blacklisted[section] = true

	for _, ref in ipairs(section.refs) do
		HL:update_size_rec(ref.part, delta_size, blacklisted)
	end
end

function HL:insert_section(ll_elem)
	local line = ll_elem.str
	local name = trim1(line:sub(3))

	local hl_elem = {
		type = HL_ELEM_TYPE.SECTION_PART,
		name = name,
		lines = LL:new(),
		size = 0,

	}

	hl_elem.ll_elem = ll_elem
	ll_elem.hl_elem = hl_elem

	local section = self.sections[name]
	if not section then
		 section = {
			name = name,
			parts = LL:new(),
			size = 0,

			refs = {},

		}
		self.sections[name] = section
	end


	section.parts:push_back(hl_elem)
	hl_elem.section = section

	local toremove = {}

	local elem = ll_elem.next
	while elem do
		if elem.hl_elem then
			if elem.hl_elem.type == HL_ELEM_TYPE.SECTION_PART then
				break
			else
				table.insert(toremove, elem.hl_elem)
			end
		end
		elem = elem.next
	end

	local elem_sizes = {}
	local remove_total = 0
	for _, elem in ipairs(toremove) do
		local elem_size = self:get_size(elem)
		table.insert(elem_sizes, elem_size)
		remove_total = remove_total + elem_size
	end

	if remove_total > 0 then
		local nt_infos = self:get_nt_from_hl_elem(toremove[1]) 

		for _, cb in ipairs(change_callbacks) do
			cb(nt_infos, 0, remove_total, toremove[1])
		end
	end


	for i, elem_size in ipairs(elem_sizes) do
		self:update_size_rec(toremove[i].part, -elem_size)
	end

	for _, elem in ipairs(toremove) do
		elem.part.lines:remove(elem)
		elem.part = nil
	end

	for _, elem in ipairs(toremove) do
		elem.part = hl_elem
		elem.part.lines:push_back(elem)
	end

	for i, elem_size in ipairs(elem_sizes) do
		self:update_size_rec(toremove[i].part, elem_size)
		if elem_size > 0 then
			local nt_infos = self:get_nt_from_hl_elem(toremove[i]) 
			for _, cb in ipairs(change_callbacks) do
				cb(nt_infos, elem_size, 0, toremove[i])
			end
		end

	end


	return hl_elem
end

function HL:insert_reference(ll, ll_elem)
	local line = ll_elem.str
	local _, _, prefix, name = line:find("^(%s*);%s*(.-)%s*$")

	local hl_elem = {
		type = HL_ELEM_TYPE.REFERENCE,
		name = name,
		prefix = prefix,
	}

	hl_elem.ll_elem = ll_elem
	ll_elem.hl_elem = hl_elem

	if not ll_elem.prev then
		local fallback_section = self.sections[ll]
		if not fallback_section then
			fallback_section = {
				name = ll,
				parts = LL:new(),
				size = 0,

				refs = {},

			}

			local fallback_section_part = {
				name = ll,
				lines = LL:new(),
				size = 0,

			}

			fallback_section.parts:push_back(fallback_section_part)
			fallback_section_part.section = fallback_section
			self.sections[ll] = fallback_section
		end

		hl_elem.part = fallback_section.parts.head
		hl_elem.part.lines:push_front(hl_elem)
	elseif ll_elem.prev.hl_elem.type == HL_ELEM_TYPE.SECTION_PART then
		hl_elem.part = ll_elem.prev.hl_elem
		hl_elem.part.lines:push_front(hl_elem)
	elseif ll_elem.prev.hl_elem.type == HL_ELEM_TYPE.META_SECTION then
		local fallback_section = self.sections[ll]
		if not fallback_section then
			fallback_section = {
				name = ll,
				parts = LL:new(),
				size = 0,

				refs = {},

			}

			local fallback_section_part = {
				name = ll,
				lines = LL:new(),
				size = 0,

			}

			fallback_section.parts:push_back(fallback_section_part)
			fallback_section_part.section = fallback_section
			self.sections[ll] = fallback_section
		end

		hl_elem.part = fallback_section.parts.head
		hl_elem.part.lines:push_front(hl_elem)
	else
		hl_elem.part = ll_elem.prev.hl_elem.part
		hl_elem.part.lines:insert(hl_elem, ll_elem.prev.hl_elem)
	end

	local ref_section = self.sections[name]
	if not ref_section then
		ref_section = {
			name = name,
			parts = LL:new(),
			size = 0,

			refs = {},

		}

		self.sections[name] = ref_section

	end
	table.insert(ref_section.refs, hl_elem)


	local blacklisted = {}
	local section = self.sections[name]
	blacklisted[section] = true
	self:update_size_rec(hl_elem.part, section.size, blacklisted)

	if section.size > 0 then
		local nt_infos = self:get_nt_from_hl_elem(hl_elem)
		for _, cb in ipairs(change_callbacks) do
			cb(nt_infos, section.size, 0, hl_elem)
		end
	end

	return hl_elem
end

function HL:insert_text(ll, ll_elem)
	local hl_elem = {
		type = HL_ELEM_TYPE.TEXT,
	}

	hl_elem.ll_elem = ll_elem
	ll_elem.hl_elem = hl_elem

	if not ll_elem.prev then
		local fallback_section = self.sections[ll]
		if not fallback_section then
			fallback_section = {
				name = ll,
				parts = LL:new(),
				size = 0,

				refs = {},

			}

			local fallback_section_part = {
				name = ll,
				lines = LL:new(),
				size = 0,

			}

			fallback_section.parts:push_back(fallback_section_part)
			fallback_section_part.section = fallback_section
			self.sections[ll] = fallback_section
		end

		hl_elem.part = fallback_section.parts.head
		hl_elem.part.lines:push_front(hl_elem)
	elseif ll_elem.prev.hl_elem.type == HL_ELEM_TYPE.SECTION_PART then
		hl_elem.part = ll_elem.prev.hl_elem
		hl_elem.part.lines:push_front(hl_elem)
	elseif ll_elem.prev.hl_elem.type == HL_ELEM_TYPE.META_SECTION then
		local fallback_section = self.sections[ll]
		if not fallback_section then
			fallback_section = {
				name = ll,
				parts = LL:new(),
				size = 0,

				refs = {},

			}

			local fallback_section_part = {
				name = ll,
				lines = LL:new(),
				size = 0,

			}

			fallback_section.parts:push_back(fallback_section_part)
			fallback_section_part.section = fallback_section
			self.sections[ll] = fallback_section
		end

		hl_elem.part = fallback_section.parts.head
		hl_elem.part.lines:push_front(hl_elem)
	else
		hl_elem.part = ll_elem.prev.hl_elem.part
		hl_elem.part.lines:insert(hl_elem, ll_elem.prev.hl_elem)
	end

	self:update_size_rec(hl_elem.part, 1)

	local nt_infos = self:get_nt_from_hl_elem(hl_elem)
	for _, cb in ipairs(change_callbacks) do
		cb(nt_infos, 1, 0, hl_elem)
	end

	return hl_elem
end

function M.remove_hl(source, ll, ll_elem)
	local hl
	if ll_elem == ll.head then
		hl = ll_to_hl[ll]

		if ll_elem.hl_elem and ll_elem.hl_elem.type == HL_ELEM_TYPE.META_SECTION then
			local line = ll_elem.str
			if hl then
				local it = ll.head.next
				while it do
					M.remove_hl(source, ll, it)
					it = it.next
				end
			end


			if ll_elem.next and ll_elem.next.hl_elem and ll_elem.next.hl_elem.type == HL_ELEM_TYPE.META_SECTION then
				line = ll_elem.next.str
				local name = trim1(line:sub(4))


				local hl_path = M.get_hl_path(source, name)
				hl = M.get_hl(hl_path)

				local it = ll.head.next.next
				ll_to_hl[ll] = hl
				while it do
					M.insert_hl(source, ll, it)
					it = it.next
				end

			else
				hl = HL:new()

				local it = ll.head.next
				ll_to_hl[ll] = hl
				while it do
					M.insert_hl(source, ll, it)
					it = it.next
				end

			end
		elseif ll_elem.next and ll_elem.next.hl_elem and  ll_elem.next.hl_elem.type == HL_ELEM_TYPE.META_SECTION then
			if hl then
				local it = ll.head.next
				while it do
					M.remove_hl(source, ll, it)
					it = it.next
				end
			end

			local line = ll_elem.next.str

			local name = trim1(line:sub(4))

			local hl_path = M.get_hl_path(source, name)
			hl = M.get_hl(hl_path)

			local it = ll.head.next.next
			ll_to_hl[ll] = hl
			while it do
				M.insert_hl(source, ll, it)
				it = it.next
			end

		end
	end

	local hl_elem = ll_elem.hl_elem
	local hl = ll_to_hl[ll]
	if hl_elem then
		if hl_elem.type == HL_ELEM_TYPE.TEXT then
			hl:remove_text(ll_elem)
		elseif hl_elem.type == HL_ELEM_TYPE.SECTION_PART then
			hl:remove_section(ll, ll_elem)
		elseif hl_elem.type == HL_ELEM_TYPE.REFERENCE then
			hl:remove_reference(ll_elem)
		elseif hl_elem.type == HL_ELEM_TYPE.META_SECTION then
			hl:remove_meta_section(ll_elem)
		elseif hl_elem.type == HL_ELEM_TYPE.FILLER then
			hl:remove_filler(ll_elem)

		end
	end
end

function HL:remove_section(ll, ll_elem)
	local hl_elem = ll_elem.hl_elem
	local hl_elem_line = hl_elem.lines.head
	local hl_elem_lines = {}
	while hl_elem_line do
		table.insert(hl_elem_lines, hl_elem_line)
		hl_elem_line = hl_elem_line.next
	end

	local size_total = self:get_size_list(hl_elem_lines)

	if size_total > 0 then
		local nt_infos = self:get_nt_from_hl_elem(hl_elem) 

		for _, cb in ipairs(change_callbacks) do
			cb(nt_infos, 0, size_total, hl_elem)
		end
	end

	self:update_size_rec(hl_elem, -size_total)

	local it = ll_elem.prev
	local prev_part = nil
	while it do
		if it.hl_elem and it.hl_elem.type == HL_ELEM_TYPE.SECTION_PART then
			prev_part = it.hl_elem
			break
		end
		it = it.prev
	end

	if not prev_part then
		local fallback_section = self.sections[ll]
		if not fallback_section then
			fallback_section = {
				name = ll,
				parts = LL:new(),
				size = 0,

				refs = {},

			}

			local fallback_section_part = {
				name = ll,
				lines = LL:new(),
				size = 0,

			}

			fallback_section.parts:push_back(fallback_section_part)
			fallback_section_part.section = fallback_section
			self.sections[ll] = fallback_section
		end

		prev_part = fallback_section.parts.head
	end

	local removed = {}
	local elem = hl_elem.lines.head
	while elem do
		local toremove = elem
		elem = elem.next
		table.insert(removed, toremove)
		hl_elem.lines:remove(toremove)
	end

	local hook_elem = removed[1]

	for _, hl_elem_line in ipairs(hl_elem_lines) do
		hl_elem_line.part = prev_part
	end

	for _, elem in ipairs(removed) do
		prev_part.lines:push_back(elem)
	end

	size_total = self:get_size_list(hl_elem_lines)
	self:update_size_rec(prev_part, size_total)


	if size_total > 0 then
		local nt_infos = self:get_nt_from_hl_elem(hook_elem) 
		for _, cb in ipairs(change_callbacks) do
			cb(nt_infos, size_total, 0, hook_elem)
		end
	end

	hl_elem.section.parts:remove(hl_elem)

	-- ;; remove section if not more parts
	-- if hl_elem.section.parts:is_empty() then
		-- self.sections[hl_elem.section.name] = nil
	-- end

	for _, cb in ipairs(root_callbacks) do
		cb(self, hl_elem.section, false)
	end

	ll_elem.hl_elem = nil

	-- ; remove section if not more parts
end

function HL:get_size_list(hl_elems)
	local size_total = 0
	for _, hl_elem in ipairs(hl_elems) do
		size_total = size_total + self:get_size(hl_elem)
	end
	return size_total
end

function HL:remove_reference(ll_elem)
	local name = ll_elem.hl_elem.name
	local hl_elem = ll_elem.hl_elem
	local blacklist = {}
	local section = self.sections[name]
	blacklist[section] = true
	self:update_size_rec(hl_elem.part, -section.size, blacklist)

	if section.size > 0 then
		local nt_infos = self:get_nt_from_hl_elem(hl_elem)
		for _, cb in ipairs(change_callbacks) do
			cb(nt_infos, 0, section.size, hl_elem)
		end
	end

	for i, ref in ipairs(section.refs) do
		if ref == hl_elem then
			table.remove(section.refs, i)
			break
		end
	end

	hl_elem.part.lines:remove(hl_elem)

	ll_elem.hl_elem = nil

	-- ; remove section if no more ref
end

function HL:remove_text(ll_elem)
	local hl_elem = ll_elem.hl_elem
	local nt_infos = self:get_nt_from_hl_elem(hl_elem)
	for _, cb in ipairs(change_callbacks) do
		cb(nt_infos, 0, 1, hl_elem)
	end

	self:update_size_rec(hl_elem.part, -1)

	hl_elem.part.lines:remove(hl_elem)

	ll_elem.hl_elem = nil

end

function M.get_hl_path(source, name)
	if type(source) == "number" then
		source = vim.api.nvim_buf_get_name(source)
	end

	local parentdir = vim.fs.dirname(source)
	local joined = vim.fs.joinpath(parentdir, name)
	return joined

end

function M.get_hl(hl_path)
	local hl = hl_path_to_hl[hl_path]
	if not hl then
		hl = HL:new()
		hl_path_to_hl[hl_path] = hl
		hl_to_hl_path[hl] = hl_path


		local parent_path = vim.fs.dirname(hl_path)
		local dir = vim.fs.joinpath(parent_path, M.ntangle_folder)
		local info = vim.uv.fs_statfs(dir)
		local linked = {}
		if info then
			for name, filetype in vim.fs.dir(dir) do
				if filetype == "file" and vim.fn.fnamemodify(name, ":e") == "t2" then
					local fullpath = vim.fs.joinpath(dir, name)
					local f = io.open(fullpath)
					if f then
						local content = f:read("*a")
						local path = vim.uv.fs_realpath(content)
						if path then
							table.insert(linked, path)
							f:close()
						end
					end
				end
			end
		end

		local loaded = {}
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			local path = vim.api.nvim_buf_get_name(buf)
			if path then
				path = vim.uv.fs_realpath(path)
				if path then
					loaded[path] = buf
				end
			end
		end

		for _, path in ipairs(linked) do
			local loaded_buf = loaded[path]
			if not loaded_buf then
				if not lls[path] then
					local f = io.open(path)
					local lines = {}
					if f then
						for line in f:lines() do
							table.insert(lines, line)
						end
						f:close()
					end

					if #lines > 0 then
						local ll = LL:new()
						lls[path] = ll

						for _, line in ipairs(lines) do
							local ll_elem = { str = line }
							ll:push_back(ll_elem)
							M.insert_hl(path, ll, ll_elem)
						end

					end
				end
			elseif not lls[loaded_buf] then
				M.add_tmonitor(loaded_buf)
			end
		end

		return hl
	end

	return  hl

end

function HL:insert_meta_section(ll, ll_elem)
	local line = ll_elem.str
	local name = trim1(line:sub(4))

	local hl_elem = {
		type = HL_ELEM_TYPE.META_SECTION,
		name = name
	}

	hl_elem.ll_elem = ll_elem
	ll_elem.hl_elem = hl_elem

	if not ll_elem.prev then
		local fallback_section = self.sections[ll]
		if not fallback_section then
			fallback_section = {
				name = ll,
				parts = LL:new(),
				size = 0,

				refs = {},

			}

			local fallback_section_part = {
				name = ll,
				lines = LL:new(),
				size = 0,

			}

			fallback_section.parts:push_back(fallback_section_part)
			fallback_section_part.section = fallback_section
			self.sections[ll] = fallback_section
		end

		hl_elem.part = fallback_section.parts.head
		hl_elem.part.lines:push_front(hl_elem)
	elseif ll_elem.prev.hl_elem.type == HL_ELEM_TYPE.SECTION_PART then
		hl_elem.part = ll_elem.prev.hl_elem
		hl_elem.part.lines:push_front(hl_elem)
	elseif ll_elem.prev.hl_elem.type == HL_ELEM_TYPE.META_SECTION then
		local fallback_section = self.sections[ll]
		if not fallback_section then
			fallback_section = {
				name = ll,
				parts = LL:new(),
				size = 0,

				refs = {},

			}

			local fallback_section_part = {
				name = ll,
				lines = LL:new(),
				size = 0,

			}

			fallback_section.parts:push_back(fallback_section_part)
			fallback_section_part.section = fallback_section
			self.sections[ll] = fallback_section
		end

		hl_elem.part = fallback_section.parts.head
		hl_elem.part.lines:push_front(hl_elem)
	else
		hl_elem.part = ll_elem.prev.hl_elem.part
		hl_elem.part.lines:insert(hl_elem, ll_elem.prev.hl_elem)
	end

end

function HL:remove_meta_section(ll_elem)
	local hl_elem = ll_elem.hl_elem
	hl_elem.part.lines:remove(hl_elem)

	ll_elem.hl_elem = nil

end

function HL:insert_filler(ll, ll_elem)
	local hl_elem = {
		type = HL_ELEM_TYPE.FILLER,
	}

	hl_elem.ll_elem = ll_elem
	ll_elem.hl_elem = hl_elem

	if not ll_elem.prev then
		local fallback_section = self.sections[ll]
		if not fallback_section then
			fallback_section = {
				name = ll,
				parts = LL:new(),
				size = 0,

				refs = {},

			}

			local fallback_section_part = {
				name = ll,
				lines = LL:new(),
				size = 0,

			}

			fallback_section.parts:push_back(fallback_section_part)
			fallback_section_part.section = fallback_section
			self.sections[ll] = fallback_section
		end

		hl_elem.part = fallback_section.parts.head
		hl_elem.part.lines:push_front(hl_elem)
	elseif ll_elem.prev.hl_elem.type == HL_ELEM_TYPE.SECTION_PART then
		hl_elem.part = ll_elem.prev.hl_elem
		hl_elem.part.lines:push_front(hl_elem)
	elseif ll_elem.prev.hl_elem.type == HL_ELEM_TYPE.META_SECTION then
		local fallback_section = self.sections[ll]
		if not fallback_section then
			fallback_section = {
				name = ll,
				parts = LL:new(),
				size = 0,

				refs = {},

			}

			local fallback_section_part = {
				name = ll,
				lines = LL:new(),
				size = 0,

			}

			fallback_section.parts:push_back(fallback_section_part)
			fallback_section_part.section = fallback_section
			self.sections[ll] = fallback_section
		end

		hl_elem.part = fallback_section.parts.head
		hl_elem.part.lines:push_front(hl_elem)
	else
		hl_elem.part = ll_elem.prev.hl_elem.part
		hl_elem.part.lines:insert(hl_elem, ll_elem.prev.hl_elem)
	end

end

function HL:remove_filler(ll_elem)
	local hl_elem = ll_elem.hl_elem
	hl_elem.part.lines:remove(hl_elem)

	ll_elem.hl_elem = nil

end

function M.TtoNT(buf, lnum)
	local ll = lls[buf]
	if ll then
		local ll_elem = ll.head
		for i=1,lnum do
			if not ll_elem then
				return {}
			end
			ll_elem = ll_elem.next
		end

		if not ll_elem then
			return {}
		end

		local hl_elem = ll_elem.hl_elem

		if not hl_elem or hl_elem.type ~= HL_ELEM_TYPE.TEXT then
			return {}
		end

		local hl = ll_to_hl[ll]
		if not hl then
			return {}
		end

		local close = hl:get_nt_from_hl_elem(hl_elem)

		return close

	end

	return {}
end

function M.NTtoT(hl, root_section, lnum)

	local hl_elem, prefix = hl:get_hl_elem_at(root_section, lnum)
	if not hl_elem then
		return
	end

	local ll_elem = hl_elem.ll_elem
	if not ll_elem then
		return
	end

	local ll = ll_elem.list
	if not ll then
		return
	end

	local off = 0
	ll_elem = ll_elem.prev
	while ll_elem do
		off = off + 1
		ll_elem =  ll_elem.prev
	end

	return ll, off, prefix



end

function HL:get_nt_from_hl_elem(hl_elem)
	local open = { { hl_elem, 0, "" } }
	local close = { }

	if hl_elem.type == HL_ELEM_TYPE.FILLER then
		return
	end


	while #open > 0 do
		local hl_elem, off, prefix = unpack(open[#open])
		table.remove(open)

		local part
		if hl_elem.type == HL_ELEM_TYPE.SECTION_PART then
			part = hl_elem
		else
			part = hl_elem.part
		end


		if hl_elem ~= part then
			hl_elem = hl_elem.prev

			while hl_elem do
				if hl_elem.type == HL_ELEM_TYPE.META_SECTION then
					break
				end

				off = off + self:get_size(hl_elem)
				hl_elem = hl_elem.prev
			end
		end

		local section = part.section
		part = part.prev
		while part do
			off = off + part.size
			part = part.prev
		end

		if section then
			if section.root then
				table.insert(close, {self, section, off, prefix })

			else
				for _, ref in ipairs(section.refs) do
					if not self:is_recursive(ref) then
						table.insert(open, {ref, off, ref.prefix .. prefix })
					end
				end
			end

		end
	end
	return close
end

function HL:get_hl_elem_at(section, lnum, prefix)
	if not section then
		return nil
	end

	local part = section.parts.head
	local off = 0
	prefix = prefix or ""

	local hl_elem

	while part do
		if lnum < off + part.size then
			hl_elem = part.lines.head
			while hl_elem and off <= lnum do
				if hl_elem.type == HL_ELEM_TYPE.TEXT then 
					if off == lnum then
						break
					end
					off = off + 1
				elseif hl_elem.type == HL_ELEM_TYPE.REFERENCE then
					local ref_size = self:get_size(hl_elem)
					if off + ref_size <= lnum then
						off = off + ref_size
					elseif not self:is_recursive(hl_elem) then
						return self:get_hl_elem_at(self.sections[hl_elem.name], lnum - off, prefix .. hl_elem.prefix)
					else
						return
					end
				end
				hl_elem = hl_elem.next
			end

			break
		end
		off = off + part.size
		part = part.next
	end
	return hl_elem, prefix
end

function M.get_line_type(buf, lnum)
	local ll = lls[buf]
	if ll then
		local ll_elem = ll.head
		for i=1,lnum do
			if not ll_elem then
				return
			end
			ll_elem = ll_elem.next
		end

		local hl_elem = ll_elem.hl_elem
		if hl_elem then
			return hl_elem.type
		end
	end

end

function M.Tto_hl_elem(buf, lnum)
	local ll = lls[buf]
	if ll then
		local ll_elem = ll.head
		for i=1,lnum do
			if not ll_elem then
				return
			end
			ll_elem = ll_elem.next
		end

		if not ll_elem then
			return
		end

		return ll_elem.hl_elem
	end

end

function LL:new()
	local ll = {}
	ll.head = nil
	ll.tail = nil

	return setmetatable(ll, { __index = self })
end

function LL:push_back(data)
	if not self.head then
		self.head = data
		self.tail = data
		data.list = self

	else 
		self.tail.next = data
		data.prev = self.tail
		self.tail = data
		data.list = self
	end

end

function LL:is_empty()
	return self.head == nil
end

function LL:push_front(data)
	if not self.head then
		self.head = data
		self.tail = data
		data.list = self

	else
		self.head.prev = data
		data.next = self.head
		self.head = data
		data.list = self
	end

end

function LL:remove(node)
	if node.next then
		node.next.prev = node.prev 
	end

	if node.prev then
		node.prev.next = node.next 
	end

	if node == self.head then
		self.head = self.head.next
	end

	if node == self.tail then
		self.tail = self.tail.prev
	end

	node.prev = nil
	node.next = nil

end

function LL:insert(data, prev)
	if not prev then
		self:push_front(data)

	else
		data.next = prev.next
		data.prev = prev
		data.list = self

		if data.next then
			data.next.prev = data
		end

		prev.next = data

		if not data.next then
			self.tail = data
		end

	end
end

function M.on_root(cb)
	table.insert(root_callbacks, cb)
end

function M.on_change(cb)
	table.insert(change_callbacks, cb)
end

function M.indentexpr()
	local line = vim.v.lnum-1

	local buf = vim.api.nvim_get_current_buf()
	local ll = M.lls[buf]
	if not ll then
		return -1
	end
	local hl = M.ll_to_hl[ll]

	if not hl then
		return -1
	end

	local nt_infos = M.TtoNT(buf, line)
	local root_section
	local line
	local root_section
	local bufnr
	local prefix
	for _, nt_info in ipairs(nt_infos) do
		root_section = nt_info[2]
		line = nt_info[3]
		prefix = nt_info[4]
	  bufnr = M.root_to_mirror_buf[root_section]
		break
	end

	if #nt_infos == 0 or not bufnr then
		return -1
	end

	local found, mod  = pcall(require, "nvim-treesitter.indent")
	if found then
		return vim.api.nvim_buf_call(bufnr, function()
			local indent = mod.get_indent(line+1) 
			if indent >= 0 then
				local num_spaces = 0
				if #prefix > 0 then
					if prefix:sub(1,1) == "\t" then
						num_spaces = #prefix * vim.o.ts
					else
						num_spaces = #prefix
					end
				end
				return math.max(indent-num_spaces, 0)
			end
			return indent
		end)
	end

end

function M.run_index_test(trials)
	local buf = vim.api.nvim_get_current_buf()

	local count = vim.api.nvim_buf_line_count(buf)


	local success = 0
	local total = 0

	local failures = {}

	trials = trials or 100
	for i=1,trials do
		local lnum = math.random(0,count-1)

		local nt_info = M.TtoNT(buf, lnum)
		if nt_info and #nt_info > 0 then
			local hl, section, off, _ = unpack(nt_info[1])
			local t_info = M.NTtoT(hl, section, off)
			if t_info then
				local _, ret_lnum = unpack(t_info)
				if ret_lnum == lnum then
					success = success + 1
				else
					total = total + 1
					table.insert(failures, lnum)

				end
			else
				total = total + 1
				table.insert(failures, lnum)

			end
		end

	end

	local result = {}
	result.total = total
	result.success = success
	result.failures = failures
	return result
end

function M.start()
	M.on_root(function(hl, root_section, added)
		if added then
			local buf = vim.api.nvim_create_buf(true, true)
			vim.api.nvim_set_option_value("undolevels", -1, { buf = buf })
			-- vim.api.nvim_buf_set_name(buf, root_section.name)

			local ft = vim.filetype.match({filename = root_section.name})
			local lang
			if ft then
				buf_filetype[buf] = ft
				lang = vim.treesitter.language.get_lang(ft)
			end


			mirror_buf_to_root[buf] = root_section
			root_to_mirror_buf[root_section] = buf

			M.buf_to_hl[buf] = hl

			if lang then
				local attached_lls = {}
				for _ll, _hl in pairs(ll_to_hl) do
					if _hl == hl then
						attached_lls[_ll] = true
					end
				end


				local found, parsers = pcall(require, "nvim-treesitter.parsers")
				local parser_installed = false
				if found then
					parser_installed = parsers.has_parser(lang)
				end


				if parser_installed then
					for _, highlighter in pairs(vim.treesitter.highlighter.active) do
						local ll = lls[highlighter.bufnr]
						if ll and attached_lls[ll] then
							highlighter.trees[buf] = vim.treesitter.get_parser(buf, lang)
						end
					end
				end
			end

			local lspconfig_found, lspconfig = pcall(require, "lspconfig")
			if lang and lspconfig_found then
				local util = require"lspconfig.util"
				local configs = util.get_config_by_ft(lang)
				if #configs > 0 then
					local config = configs[1]
					local hl_path = M.hl_to_hl_path[hl]
					if hl_path then
						local parent_path = vim.fs.dirname(hl_path)
						local bufname = vim.fs.joinpath(parent_path, M.ntangle_folder, root_section.name)
						local buf_path = util.path.sanitize(bufname)
						local uri = vim.uri_from_fname(buf_path)
						M.buf_to_uri[buf] = uri
						M.uri_to_buf[uri] = buf
						local manager = config.manager
						if manager then
							local root_dir
							if config.get_root_dir then
								root_dir = config.get_root_dir(buf_path, buf)
							end

							if root_dir then
								manager:add(root_dir, false, buf)

							elseif manager.config.single_file_support then
								local pseudo_root = vim.fs.dirname(buf_path)

								manager:add(pseudo_root, true, buf)

							end
						end
					end

				end
			end


			if ft then
				vim.o.eventignore = "all"
				vim.bo[buf].ft = ft
				vim.o.eventignore = ""
			end


			num_root[buf] = 0

		else
			local buf = root_to_mirror_buf[root_section]
			if buf then
				vim.schedule(function()
					vim.api.nvim_buf_delete(buf, { force = true })
				end)
				root_to_mirror_buf[root_section] = nil
				mirror_buf_to_root[buf] = nil

				for buf, section in pairs(mirror_buf_to_root) do
					if root_section == section then
						root_to_mirror_buf[root_section] = buf
						break
					end
				end


				M.buf_to_hl[buf] = nil

			end

		end
	end)

	M.on_change(function(nt_infos, lnum_add, lnum_rem, hl_elem)
		if lnum_add > 0 then
			table.sort(nt_infos, function(a,b) 
				return a[3] < b[3]
			end)
		else
			table.sort(nt_infos, function(a,b) 
				return a[3] > b[3]
			end)
		end

		local prev_hl
		local lines = {}

		for _, nt_info in ipairs(nt_infos) do
			local hl, section, off, prefix = unpack(nt_info)
			local buf = root_to_mirror_buf[section]

			if buf then
				if hl ~= prev_hl then
					lines = {}
					hl:getlines(hl_elem, lnum_add, lines)
					prev_hl = hl
				end

				local buf_empty = num_root[buf] == 0

				local prefix_lines = {}
				for i=1,#lines do
					table.insert(prefix_lines, prefix .. lines[i]) 
				end

				if buf_empty then
					vim.api.nvim_buf_set_lines_unsafe(buf, 0, -1, false, prefix_lines)
				else
					vim.api.nvim_buf_set_lines_unsafe(buf, off, off+lnum_rem, false, prefix_lines)
				end

				num_root[buf] = num_root[buf] + lnum_add - lnum_rem

			end
		end
	end)

	M.monitor()
end

function M.add_tmonitor(buf)
	buf = buf == 0 and vim.api.nvim_get_current_buf() or buf

	if lls[buf] then
		return
	end


	local file_added = false
	local ll
	local path = vim.api.nvim_buf_get_name(buf)
	path = vim.uv.fs_realpath(path)
	ll = lls[path]
	if ll then
		file_added = true 
		lls[buf] = ll
		lls[path] = nil
	end


	if not file_added then
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

		ll = LL:new()
		lls[buf] = ll

		for i, line in ipairs(lines) do
			local ll_elem = { str = line }
			ll:push_back(ll_elem)

			M.insert_hl(buf, ll, ll_elem)

		end
		local ll_elem = { line = nil }
		ll:push_back(ll_elem)
		M.insert_hl(buf, ll, ll_elem)


	end

	vim.api.nvim_buf_attach(buf, false, {
		on_bytes = function(...)
			local args = { ... }

			local res = ll_to_hl[ll]
			res = ll_to_hl[ll]

			local srow = args[4]
			local scol = args[5]

			local orow = args[7]
			local ocol = args[8]

			local nrow = args[10]
			local ncol = args[11]


			local line = ll.head

			for i=1,srow do
				line = line.next
			end

			if orow == 0 and nrow == 0 and line.hl_elem.type == HL_ELEM_TYPE.TEXT then
				local new_text = vim.api.nvim_buf_get_lines(buf, srow, srow+1, true)
				if M.parse_line(line.str) == HL_ELEM_TYPE.TEXT then
					line.str = new_text[1]
					M.update_text(ll, line)

				else
					M.remove_hl(buf, ll, line)
					line.str = new_text[1]
					M.insert_hl(buf, ll, line)

				end

			elseif nrow == 0 and orow == 0 then
				local new_text = vim.api.nvim_buf_get_lines(buf, srow, srow+1, false)
				M.remove_hl(buf, ll, line)
				line.str = new_text[1]
				M.insert_hl(buf, ll, line)

			else
				local first_line

				if orow ~= 0 or ocol ~= 0 then
					for i=0,orow do
						if i == 0 then
							first_line = line

							if orow > 0 then
								M.remove_hl(buf, ll, line)
								line.str = line.str:sub(1,scol)
								M.insert_hl(buf, ll, line)
								line = line.next

							elseif orow == 0 then
								M.remove_hl(buf, ll, line)
								line.str = line.str:sub(1,scol) .. line.str:sub(scol+ocol+1)
								M.insert_hl(buf, ll, line)

							end

						elseif i == orow then
							if not line.str then
								if line.prev then
									local toremove = line.prev
									M.remove_hl(buf, ll, toremove)
									ll:remove(toremove)
								end

							else
								local suffix = line.str:sub(ocol+1)
								if suffix ~= "" then
									M.remove_hl(buf, ll, first_line)
									first_line.str = first_line.str .. suffix
									M.insert_hl(buf, ll, first_line)
								end

								M.remove_hl(buf, ll, line)
								ll:remove(line)
								line = first_line
							end

						else
							local toremove = line
							line = line.next
							M.remove_hl(buf, ll, toremove)
							ll:remove(toremove)

						end
					end
				end

				local appended_lines = vim.api.nvim_buf_get_lines(buf, srow, srow+nrow+1, false)

				local suffix_first_line = ""

				if ncol ~= 0 or nrow ~= 0 then
					for i=0,nrow do
						local replace_filler = false
						if i == 0 then
							local inserted
							if nrow == 0 then
								inserted = appended_lines[1]:sub(scol+1, scol+ncol)

								if inserted ~= "" then
									M.remove_hl(buf, ll, line)
									if not line.str then
										replace_filler = true
										line.str = line.str or ""
									end

									line.str = line.str:sub(1,scol) .. inserted .. line.str:sub(scol+1)
									M.insert_hl(buf, ll, line)
								end
							else
								inserted = appended_lines[1]:sub(scol+1)

								if not line.str then
									replace_filler = true
									line.str = line.str or ""
								end

								suffix_first_line = line.str:sub(scol+1)

								if inserted ~= "" or suffix_first_line ~= "" then
									M.remove_hl(buf, ll, line)
									line.str = line.str:sub(1,scol) .. inserted
									M.insert_hl(buf, ll, line)
								else
									replace_filler = false
								end
							end

						elseif i == nrow then
							local prefix = appended_lines[#appended_lines]:sub(1,ncol)

							if not line.str then
								replace_filler = true
								line.str = line.str or ""
							end

							if prefix ~= "" or suffix_first_line ~= "" then
								line.str = prefix .. suffix_first_line
								M.insert_hl(buf, ll, line)
							else
								replace_filler = false
							end

						else
							if not line.str then
								replace_filler = true
								line.str = line.str or ""
							end

							line.str = appended_lines[i+1]
							M.insert_hl(buf, ll, line)

						end
						if i < nrow and not replace_filler then
							local new_line = { str = "" }
							ll:insert(new_line, line)
							line = new_line
						end

						if replace_filler then
							local new_line = { str = nil }
							ll:insert(new_line, line)
							line = new_line
						end

					end
				end



			end
		end
	})

end

function M.update_text(ll, ll_elem)
	local hl_elem = ll_elem.hl_elem
	local hl = ll_to_hl[ll]
	if hl then
		local nt_infos = hl:get_nt_from_hl_elem(hl_elem)
		for _, cb in ipairs(change_callbacks) do
			cb(nt_infos, 1, 1, hl_elem)
		end
	end

end

function M.monitor()
	local bufs = vim.api.nvim_list_bufs()

	local t2_bufs = {}
	for _, buf in ipairs(bufs) do
		source = vim.api.nvim_buf_get_name(buf)
		if source:match('%.t2$') then
			table.insert(t2_bufs, buf)
		end
	end


	for _, buf in ipairs(t2_bufs) do
		M.add_tmonitor(buf)
	end

	vim.api.nvim_create_augroup("ntangle-inc", { clear = false })
	local autocmds = vim.api.nvim_get_autocmds({group = "ntangle-inc"})
	if #autocmds == 0 then
		vim.api.nvim_create_autocmd({"BufNewFile", "BufReadPost"}, {
			pattern = {"*.t2"},
			callback = function(ev)
				vim.treesitter.highlighter.new(ev.buf, {})

				M.add_tmonitor(ev.buf)
				vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

				-- Buffer local mappings.
				-- See `:help vim.lsp.*` for documentation on any of the below functions
				local opts = { buffer = ev.buf }
				vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
				vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
				vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
				vim.bo[ev.buf].indentexpr = "v:lua.require'ntangle-inc'.indentexpr()"

			end
		})
	end

end

return M

