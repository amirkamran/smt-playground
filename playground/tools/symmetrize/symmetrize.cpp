#include <iostream>
#include <set>
#include <string>
#include <sstream>
#include <vector>
#include <cstdlib>
#include <boost/foreach.hpp>
#include <boost/iostreams/device/file.hpp>
#include <boost/iostreams/filter/gzip.hpp> 
#include <boost/iostreams/device/file_descriptor.hpp>
#include <boost/iostreams/filtering_stream.hpp> 
#include <boost/algorithm/string/predicate.hpp>
#include <boost/algorithm/string/classification.hpp>
#include <boost/algorithm/string/split.hpp>
#include <boost/function.hpp>
#include <boost/bind.hpp>

using namespace boost::algorithm;
using namespace boost::iostreams;
using namespace boost;
using namespace std;

void Die(const string &msg) {
  cerr << msg << endl;
  exit(1);
}

// initialize input stream, either plain or gzipped file
filtering_istream *initInput(const string &fileName)
{
  filtering_istream *in = new filtering_istream();
  if (fileName.empty()) {
    in->push(cin);
  } else {
    if (ends_with(fileName, ".gz"))
      in->push(gzip_decompressor());
    file_source fileSrc(fileName.c_str());
    if (! fileSrc.is_open())
      Die("Cannot read file: " + fileName);
    in->push(fileSrc);
  }
  return in;
}

// alignment point
struct Point {
  Point() {}
  Point(int x, int y) : x(x), y(y) {}

  int x, y;
};

// compare alignment points
bool operator <(const Point &p1, const Point &p2) {
  return p1.x != p2.x ? p1.x < p2.x : p1.y < p2.y;
}

// word alignment type
typedef set<Point> AlignType;

// quick line reader, build AlignType
AlignType parseLine(const string &line) {
  AlignType align;
  Point pt;
  int num = 0;
  BOOST_FOREACH(char c, line) {
    if (c >= '0' && c <= '9') {
      num = num * 10 + (c - '0');      
    } else if (c == '-') {
      pt.x = num;
      num = 0;
    } else if (c == ' ') {
      pt.y = num;
      num = 0;
      align.insert(pt);
      pt.x = -1; 
    } else {
      Die("Unexpected character " + c);
    }
  }
  if (pt.x != -1) {
    pt.y = num;
    align.insert(pt);
  }
  return align;
}

// state of symmetrization:
// - current points
// - extra points that can be added by symmetrization algorithms
// - currently aligned points on the source and target sides
struct State {
  AlignType current, extra;
  set<int> alignedSrc, alignedTgt;
};

// add point to alignment, i.e. move point from extra pts. to current pts.
// also remove its words from the sets of unaligned items
bool movePoint(State &state, const Point &pt) {
  if (state.extra.erase(pt) == 1) {
    state.current.insert(pt);
    state.alignedSrc.insert(pt.x);
    state.alignedTgt.insert(pt.y);
    return true;
  } else {
    return false;
  }
}

// either source or target side of the point is unaligned
bool unalignedOr(const State &state, const Point &pt) {
  return state.alignedSrc.find(pt.x) == state.alignedSrc.end()
    || state.alignedTgt.find(pt.y) == state.alignedTgt.end();
}

// both source and target side of the point is unaligned
bool unalignedAnd(const State &state, const Point &pt) {
  return state.alignedSrc.find(pt.x) == state.alignedSrc.end()
    && state.alignedTgt.find(pt.y) == state.alignedTgt.end();
}

// add point to alignment if it is unalignedOr
bool moveUnalignedPoint(State &state, const Point &pt) {
  if (unalignedOr(state, pt)) {
    return movePoint(state, pt);
  } else {
    return false;
  }
}

//
// symmetrization algorithms
//

// union, move all points from extra to current
void U(State &s) {
  AlignType::iterator it, toMove;
  it = s.extra.begin();
  while (it != s.extra.end()) {
    toMove = it; ++it;
    movePoint(s, *toMove);
  }
}

// grow(-diag)
void G(State &s, const vector<Point> &neighbors) {
  bool changed = true;
  while (changed) {
    changed = false;
    BOOST_FOREACH(const Point &pt, s.current) {
      BOOST_FOREACH(const Point &n, neighbors) {
        changed = changed || moveUnalignedPoint(s, Point(pt.x + n.x, pt.y + n.y));
      }
    }
  }
}

// final
void F(State &s) {
  AlignType::iterator it, toMove;
  it = s.extra.begin();
  while (it != s.extra.end()) {
    toMove = it; ++it;
    moveUnalignedPoint(s, *toMove);
  }
}

// final-and
void FA(State &s) {
  AlignType::iterator it, toMove;
  it = s.extra.begin();
  while (it != s.extra.end()) {
    toMove = it; ++it;
    if (unalignedAnd(s, *toMove)) movePoint(s, *toMove);
  }
}

// initial alignment to start the symmetrization with
// either left, right or intersection
enum Initial { INTER, LEFT, RIGHT };

// return alignment based on Initial enum value
const AlignType &GetInitial(const AlignType &l, const AlignType &r, 
    const AlignType &i, Initial init) {
  switch (init) {
    case LEFT:  return l;
    case RIGHT: return r;
    case INTER: return i;
    default: assert(false);
  }
}

// define function pointer type for symmetrization algorithms
typedef function<void (State &)> AlgType;

// print program usage
string Usage() {
  return "Usage: symmetrize align.left align.right symmetrization [symmetrization2 [...]]"
    "\n\nSupported algorithms: l, r, i, u, g, d, f, fa"
    "\nAlgorithms can be combined, e.g. g+d+fa"
    "\nMultiple symmetrizations are separated by tabs in the output.";
}

// print word alignment
void PrintAlign(const AlignType &ali) {
  AlignType::const_iterator it = ali.begin();
  while (it != ali.end()) {
    cout << it->x << '-' << it->y;
    if (++it != ali.end()) cout << ' ';
  }
}

int main(int argc, char **argv) {
  size_t lines = 0;
  if (argc < 4) {
    Die(Usage());
  }

  // initialize file streams
  istream *leftHdl = initInput(argv[1]);
  istream *rightHdl = initInput(argv[2]);

  vector<vector<AlgType> > syms; // requested symmetrizations
  vector<Initial> inits;         // their respective initial alignments

  vector<Point> neighbors;
  neighbors.push_back(Point(-1, 0));
  neighbors.push_back(Point(0, -1));
  neighbors.push_back(Point(1, 0));
  neighbors.push_back(Point(0, 1));

  vector<Point> neighborsDiag(neighbors);
  neighborsDiag.push_back(Point(-1, -1));
  neighborsDiag.push_back(Point(-1, 1));
  neighborsDiag.push_back(Point(1, -1));
  neighborsDiag.push_back(Point(1, 1));

  // parse command-line arguments, get symmetrizations
  for (int i = 3; i < argc; i++) {
    vector<string> algs;
    split(algs, argv[i], is_any_of("+"));
    vector<AlgType> sym;
    Initial init = INTER;
    BOOST_FOREACH(const string &s, algs) {
      if (s == "i") {
        // do nothing, we start with intersection
      } else if (s == "u") {
        sym.push_back(U);
      } else if (s == "g") {
        sym.push_back(bind(G, _1, neighbors));
      } else if (s == "gd") {
        sym.push_back(bind(G, _1, neighborsDiag));
      } else if (s == "f") {
        sym.push_back(F);
      } else if (s == "fa") {
        sym.push_back(FA);
      } else if (s == "l") {
        init = LEFT;
      } else if (s == "r") {
        init = RIGHT;
      } else {
        Die("Unrecognized algorithm: " + s);
      }
    }
    syms.push_back(sym);
    inits.push_back(init);
  }

  // go over the alignment, compute symmetrizations
  string leftLine, rightLine;
  while (getline(*leftHdl, leftLine)) {
    if (++lines % 10000 == 0) cerr << '.';
    if (! getline(*rightHdl, rightLine))
      Die("Right alignment file too short");

    // read alignment lines
    AlignType leftAli  = parseLine(leftLine);
    AlignType rightAli = parseLine(rightLine);

    // pre-compute alignment intersection
    AlignType intersection;
    set_intersection(leftAli.begin(), leftAli.end(),
        rightAli.begin(), rightAli.end(),
        inserter(intersection, intersection.begin()));

    // go over requested symmetrizations
    for (size_t i = 0; i < syms.size(); i++) {
      State state;

      // initialize currently aligned points
      state.current = GetInitial(leftAli, rightAli, intersection, inits[i]);
      BOOST_FOREACH(const Point &pt, state.current) {
        state.alignedSrc.insert(pt.x);
        state.alignedTgt.insert(pt.y);
      }

      // initialize extra points
      set_difference(leftAli.begin(), leftAli.end(), state.current.begin(), state.current.end(),
          inserter(state.extra, state.extra.begin()));
      set_difference(rightAli.begin(), rightAli.end(), state.current.begin(), state.current.end(),
          inserter(state.extra, state.extra.begin()));

      // run symmetrization algorithms
      BOOST_FOREACH(const AlgType &alg, syms[i]) {
        alg(state);
      }
      PrintAlign(state.current);
      if (i < syms.size() - 1) cout << "\t";
    }
    cout << "\n";
  }
  if (getline(*rightHdl, rightLine))
    Die("Left alignment file too short");
}
