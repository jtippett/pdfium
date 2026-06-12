CUSTOM_DIR = custom

# Build against the locally installed Erlang/OTP rather than a pinned version,
# so the NIF matches the runtime that loads it (e.g. OTP 28 -> NIF 2.17,
# OTP 29 -> NIF 2.18). build-for-mac.sh maps the OTP major to a builds.json
# entry; build-for-linux.sh uses the system OTP headers directly.
HOST_OS := $(shell uname -s)
HOST_ARCH := $(shell uname -m)
OTP_MAJOR := $(shell erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().')

ifeq ($(HOST_OS),Darwin)
TARGETS = priv/libpdfium.dylib priv/pdfium_nif.so
BUILD_CMD = ./build-for-mac.sh macos $(HOST_ARCH) $(OTP_MAJOR)
else
TARGETS = priv/libpdfium.so priv/pdfium_nif.so
BUILD_CMD = ./build-for-linux.sh $(HOST_ARCH)
endif

all: $(TARGETS)

$(TARGETS): c_src/pdfium_nif.cpp
	cd $(CUSTOM_DIR) && $(BUILD_CMD)

clean:
	rm -rf $(TARGETS)

.PHONY: all clean
