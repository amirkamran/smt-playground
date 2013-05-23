BOOST_PATH = /a/merkur3/TMP/tamchyna/boost_1_50_0/install/
CXX_FLAGS = -O3 -g -Wall
LD_FLAGS = -Wl,-Bstatic $(BOOST_PATH)/lib/libboost_program_options-mt.a $(BOOST_PATH)/lib/libboost_iostreams-mt.a -lz -Wl,-Bdynamic 

all: symmetrize

symmetrize: symmetrize.cpp 
	$(CXX) $(CXX_FLAGS) $< $(LD_FLAGS) -o $@ 

clean:
	rm -f symmetrize

