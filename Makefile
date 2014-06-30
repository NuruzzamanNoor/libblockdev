UTILS_FILES = src/utils/sizes.c src/utils/sizes.h src/utils/exec.c src/utils/exec.h src/utils/utils.h
LVM_PLUGIN_FILES = src/plugins/lvm.h src/plugins/lvm.c
SWAP_PLUGIN_FILES = src/plugins/swap.h src/plugins/swap.c
LOOP_PLUGIN_FILES = src/plugins/loop.h src/plugins/loop.c
CRYPTO_PLUGIN_FILES = src/plugins/crypto.h src/plugins/crypto.c
MPATH_PLUGIN_FILES = src/plugins/mpath.h src/plugins/mpath.c
DM_PLUGIN_FILES = src/plugins/dm.h src/plugins/dm.c
LIBRARY_FILES = src/lib/blockdev.c src/lib/blockdev.h src/lib/plugins.h src/lib/plugin_apis/lvm.h

build-plugins: ${LVM_PLUGIN_FILES} ${SWAP_PLUGIN_FILES} ${LOOP_PLUGIN_FILES} ${MPATH_PLUGIN_FILES}
	gcc -c -Wall -Wextra -Werror -fPIC -I src/utils/ -I src/plugins/ \
		`pkg-config --cflags glib-2.0 gobject-2.0` src/plugins/lvm.c
	gcc -shared -o src/plugins/libbd_lvm.so lvm.o

	gcc -c -Wall -Wextra -Werror -fPIC -I src/plugins/ -I src/utils/ \
		`pkg-config --cflags glib-2.0` src/plugins/swap.c
	gcc -shared -o src/plugins/libbd_swap.so swap.o

	gcc -c -Wall -Wextra -Werror -fPIC -I src/plugins/ -I src/utils/ \
		`pkg-config --cflags glib-2.0` src/plugins/loop.c
	gcc -shared -o src/plugins/libbd_loop.so loop.o

	gcc -c -Wall -Wextra -Werror -fPIC -I src/plugins/ -lm `pkg-config --libs --cflags glib-2.0 libcryptsetup`\
		src/plugins/crypto.c
	gcc -shared -o src/plugins/libbd_crypto.so crypto.o

	gcc -c -Wall -Wextra -Werror -fPIC -I src/plugins/ -I src/utils/ \
		`pkg-config --cflags glib-2.0` src/plugins/mpath.c
	gcc -shared -o src/plugins/libbd_mpath.so mpath.o

	gcc -c -Wall -Wextra -Werror -fPIC -I src/plugins/ -I src/utils/ \
		`pkg-config --cflags glib-2.0` src/plugins/dm.c
	gcc -shared -o src/plugins/libbd_dm.so dm.o

generate-boilerplate-code: src/lib/plugin_apis/lvm.h src/lib/plugin_apis/swap.h
	./boilerplate_generator.py src/lib/plugin_apis/lvm.h > src/lib/plugin_apis/lvm.c
	./boilerplate_generator.py src/lib/plugin_apis/swap.h > src/lib/plugin_apis/swap.c
	./boilerplate_generator.py src/lib/plugin_apis/loop.h > src/lib/plugin_apis/loop.c
	./boilerplate_generator.py src/lib/plugin_apis/crypto.h > src/lib/plugin_apis/crypto.c
	./boilerplate_generator.py src/lib/plugin_apis/mpath.h > src/lib/plugin_apis/mpath.c
	./boilerplate_generator.py src/lib/plugin_apis/dm.h > src/lib/plugin_apis/dm.c

build-utils: ${UTILS_FILES}
	gcc -c -Wall -Wextra -Werror -fPIC `pkg-config --cflags glib-2.0` -I src/utils/ \
        src/utils/sizes.c
	gcc -c -Wall -Wextra -Werror -fPIC `pkg-config --cflags glib-2.0` -I src/utils/ \
        src/utils/exec.c
	gcc -shared -o src/utils/libbd_utils.so sizes.o exec.o

build-library: generate-boilerplate-code ${LIBRARY_FILES}
	gcc -fPIC -c `pkg-config --libs --cflags glib-2.0` -ldl src/lib/blockdev.c
	gcc -shared -o src/lib/libblockdev.so blockdev.o

build-introspection-data: build-utils build-library ${LIBRARY_FILES}
	LD_LIBRARY_PATH=src/lib/:src/utils/ g-ir-scanner `pkg-config --cflags --libs glib-2.0 gobject-2.0 libcryptsetup` --library=blockdev -I src/lib/ -L src/utils -lbd_utils -L src/lib/ --identifier-prefix=BD --symbol-prefix=bd --namespace BlockDev --nsversion=1.0 -o BlockDev-1.0.gir --warn-all src/lib/blockdev.h src/lib/blockdev.c src/lib/plugins.h src/lib/plugin_apis/lvm.h src/lib/plugin_apis/swap.h src/lib/plugin_apis/loop.h src/lib/plugin_apis/crypto.h src/lib/plugin_apis/mpath.h src/lib/plugin_apis/dm.h
	g-ir-compiler -o BlockDev-1.0.typelib BlockDev-1.0.gir

test-sizes: ${SIZES_FILES}
	gcc -Wall -DTESTING_SIZES -o test_sizes -I src/utils/ -lm `pkg-config --libs --cflags glib-2.0`\
		src/utils/sizes.c
	@echo "***Running tests***"
	./test_sizes
	@rm test_sizes

test-lvm-plugin: ${LVM_PLUGIN_FILES} build-utils
	gcc -DTESTING_LVM -o test_lvm_plugin -I src/utils/ -I src/plugins/ -I src/utils/ \
		-L src/utils/ -lbd_utils -lm `pkg-config --libs --cflags glib-2.0 gobject-2.0`\
		src/plugins/lvm.c
	@echo "***Running tests***"
	LD_LIBRARY_PATH=src/utils/	./test_lvm_plugin
	@rm test_lvm_plugin

test-swap-plugin: ${SWAP_PLUGIN_FILES} build-utils
	gcc -DTESTING_SWAP -o test_swap_plugin -I src/plugins/ -I src/utils/ -L src/utils/ -lbd_utils \
		`pkg-config --libs --cflags glib-2.0` src/plugins/swap.c
	@echo "***Running tests***"
	LD_LIBRARY_PATH=src/utils/ ./test_swap_plugin
	@rm test_swap_plugin

test-loop-plugin: ${LOOP_PLUGIN_FILES} build-utils
	gcc -DTESTING_LOOP -o test_loop_plugin -I src/plugins/ -I src/utils/ -L src/utils/ -lbd_utils \
		`pkg-config --libs --cflags glib-2.0` src/plugins/loop.c
	@echo "***Running tests***"
	LD_LIBRARY_PATH=src/utils/ ./test_loop_plugin
	@rm test_loop_plugin

test-library: generate-boilerplate-code build-plugins
	gcc -DTESTING_LIB -o test_library `pkg-config --libs --cflags glib-2.0 gobject-2.0` -ldl src/lib/blockdev.c
	@echo "***Running tests***"
	LD_LIBRARY_PATH=src/plugins/ ./test_library
	@rm test_library

test-from-python: build-library build-plugins build-introspection-data
	GI_TYPELIB_PATH=. LD_LIBRARY_PATH=src/plugins/:src/lib/ python -c 'from gi.repository import BlockDev; BlockDev.init(None); print BlockDev.lvm_get_max_lv_size()'

run-ipython: build-library build-plugins build-introspection-data
	GI_TYPELIB_PATH=. LD_LIBRARY_PATH=src/plugins/:src/lib/:src/utils/ ipython

run-root-ipython: build-library build-plugins build-introspection-data
	sudo GI_TYPELIB_PATH=. LD_LIBRARY_PATH=src/plugins/:src/lib/:src/utils/ ipython

test: build-utils build-library build-plugins build-introspection-data
	@echo
	@sudo GI_TYPELIB_PATH=. LD_LIBRARY_PATH=src/plugins/:src/lib/:src/utils/ PYTHONPATH=.:tests/ \
		python -m unittest discover -v -s tests/ -p '*_test.py'
