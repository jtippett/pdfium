CUSTOM_DIR = custom
MACOS_SCRIPT = $(CUSTOM_DIR)/build-for-mac.sh
TARGETS = priv/libpdfium.dylib priv/pdfium_nif.so

# Build against the locally installed Erlang/OTP rather than a pinned version,
# so the NIF matches the runtime that loads it (e.g. OTP 28 -> NIF 2.17,
# OTP 29 -> NIF 2.18). build-for-mac.sh maps the OTP major to a builds.json entry.
HOST_ARCH := $(shell uname -m)
OTP_MAJOR := $(shell erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().')

all: $(TARGETS)

$(TARGETS): c_src/pdfium_nif.cpp
	cd custom && ./build-for-mac.sh macos $(HOST_ARCH) $(OTP_MAJOR)

clean:
	rm -rf $(TARGETS)

.PHONY: all clean
