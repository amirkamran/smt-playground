#!/home/akamran1/local/bin/python3.4

import kenlm, sys, getopt, gzip

def main(argv):
  lmfile = ""
  inputfile = ""
  try:
    opts, args = getopt.getopt(argv, "l:i:")
  except getopt.GetoptError:
    print("lmscore.py -l <lmfile> -i <inputfile")
  for opt, arg in opts:
    if opt == "-l":
       lmfile = arg
    elif opt == "-i":
       inputfile = arg
  model = kenlm.LanguageModel(lmfile)

  if inputfile.endswith(".gz"):
    f = gzip.open(inputfile)
  else:
    f = open(inputfile)

  for line in f:
    print(model.score(line)/len(line))

if __name__ == "__main__":
  main(sys.argv[1:])
