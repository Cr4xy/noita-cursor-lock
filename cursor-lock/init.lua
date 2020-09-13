-- Based on 'Shutdown' by Dexterous (https://modworkshop.net/mod/27433)
local ffi = require 'ffi'

ffi.cdef[[
uint32_t GetLastError(void);

uint32_t FormatMessageA(
	uint32_t dwFlags,
	const void* lpSource,
	uint32_t dwMessageId,
	uint32_t dwLanguageId,
	char* lpBuffer,
	uint32_t nSize,
	va_list* Arguments
);

void* LocalFree(void* hMem);

typedef struct {
	long left;
	long top;
	long right;
	long bottom;
} RECT;


long GetActiveWindow();

int GetWindowRect(
	long   hWnd,
	RECT* lpRect
);

int ClipCursor(
	const RECT *lpRect
);
]]

function format_message(error_code)
	local flags =
		0x100 +  -- FORMAT_MESSAGE_ALLOCATE_BUFFER
		0x1000 + -- FORMAT_MESSAGE_FROM_SYSTEM
		0x200 +  -- FORMAT_MESSAGE_IGNORE_INSERTS
		0xff     -- FORMAT_MESSAGE_MAX_WIDTH_MASK

	local message_arr = ffi.new('char*[1]')
	-- When using FORMAT_MESSAGE_ALLOCATE_BUFFER:
	-- Instead of passing a char* we pass a pointer to a char*, the function
	-- Allocates the memory it needs and places the pointer to that memory into
	-- the location we pass. Since this function normally takes a char* instead
	-- a char** we need to do this scary cast. We then need to free the memory
	-- with LocalFree.
	local message_ptr = ffi.cast('char*',  message_arr)

	ffi.C.FormatMessageA(flags, nil, error_code, 0, message_ptr, 0, nil)
	local message = message_arr[0]

	if message == nil then
		-- Well.. We couldn't get the error message for some reason..
		-- We can retrieve the error, and then get the error text with
		-- FormatMessageA! Oh wait..
		local err = ffi.C.GetLastError()
		error("Couldn't format error code, everything is f'ed: " .. tostring(err))
	end

	message_string = ffi.string(message)

	ffi.C.LocalFree(message)

	return message_string
end

function last_windows_error_string()
	local error_code = ffi.C.GetLastError()
	return '(' .. tostring(error_code) .. ') ' .. format_message(error_code)
end


local user32
local hwnd
local rect
function clip()
	if not user32 then user32 = ffi.load('user32') end
	if not hwnd or hwnd == 0 then hwnd = user32.GetActiveWindow() end
	if not rect then rect = ffi.new('RECT') end
	if hwnd ~= 0 then
		if user32.GetWindowRect(hwnd, rect) ~= 0 then
			if user32.ClipCursor(rect) == 0 then
				error("Failed ClipCursor: " .. last_windows_error_string())
			end
		else
			error("Failed GetWindowRect: " .. last_windows_error_string())
		end
	else
		error("Failed GetActiveWindow: " .. last_windows_error_string())
	end
end

local nextTry = 0
function OnWorldPreUpdate()
	if os.time() > nextTry then
		nextTry = os.time() + 10
		clip()
	end
end
