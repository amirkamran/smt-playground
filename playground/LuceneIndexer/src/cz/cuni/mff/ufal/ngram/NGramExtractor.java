/* 
 * This class analyze the text and calculate the different n-grams and their frequencies
 * 
 */
package cz.cuni.mff.ufal.ngram;


import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.Hashtable;

public class NGramExtractor {

	double vocabSize, textSize, entropy, perplexity;
	int n;
	NGram nGram;
	ArrayList<NGram> indexes;
	
	public NGramExtractor(int n) {
		nGram = new NGram("<ROOT>", 0);
		this.n = n;
		indexes = new ArrayList<NGram>();
		indexes.add(nGram);
	}
	
	public NGram getNGram() {
		return nGram;
	}
	
	public NGram calculateNGrams(InputStreamReader is) throws IOException {
		BufferedReader br = new BufferedReader(is);						
		while(true) {
			try {				
				String word = br.readLine();
				if(word==null) break;
				addWord(word);
			}catch(Exception e) {
				//e.printStackTrace();
				break;
			}
		}
		br.close();
		vocabSize = nGram.getNextWords().size();
		return nGram;
	}
		
	private void addWord(String word) {
		textSize++;
		ArrayList<NGram> newIndexes = new ArrayList<NGram>();
		newIndexes.add(nGram);
		for(int j=0;j<n;j++) {
			try {
				NGram item = indexes.get(j).addWord(word);
				item.level = j+1;
				newIndexes.add(item);
			} catch(Exception e) { 
				//e.printStackTrace();
				break;
			}
		}
		indexes = newIndexes;
	}
	
	public NGram calculateNGrams(String text) {
		String []words = text.split("\\s");
		for(int i=0;i<words.length;i++) {
			String word = words[i];
			addWord(word);			
		}
		vocabSize = nGram.getNextWords().size();
		return nGram;
	}
	
	public ArrayList<String> getNGrams(int n) {
		return getNGrams("", nGram.getNextWords(), n-1);
	}
	
	public ArrayList<String> getNGramsUpto(int n) {
		return getNGramsUpto("", nGram.getNextWords(), n-1);
	}
	
	private ArrayList<String> getNGramsUpto(String prefix, Hashtable<String, NGram> currentLevel, int n) {
		ArrayList<String> nGrams = new ArrayList<String>();
		if(n==0) {			
			for(String word : currentLevel.keySet()) {
				String newPrefix = prefix + " " + word;
				nGrams.add(newPrefix.trim());
			}
		} else {
			for(String word : currentLevel.keySet()) {
				String newPrefix = prefix + " " + word;
				nGrams.add(newPrefix.trim());
				nGrams.addAll(getNGramsUpto(newPrefix, currentLevel.get(word).getNextWords(), n-1));
			}
		}
		return nGrams;		
	}
	
	private ArrayList<String> getNGrams(String prefix, Hashtable<String, NGram> currentLevel, int n) {
		ArrayList<String> nGrams = new ArrayList<String>();
		if(n==0) {			
			for(String word : currentLevel.keySet()) {
				String newPrefix = prefix + " " + word;
				nGrams.add(newPrefix.trim());
			}
		} else {
			for(String word : currentLevel.keySet()) {
				String newPrefix = prefix + " " + word;
				nGrams.addAll(getNGrams(newPrefix, currentLevel.get(word).getNextWords(), n-1));
			}
		}
		return nGrams;		
	}
	
	public double getNGramCounts(int n) {
		return getNGramCounts(n, 0, 0);
	}
	
	public double getNGramCounts(int n, int havingCount, int compType) {
		double c = 0;
		ArrayList<NGram> itr = new ArrayList<NGram>();
		itr.add(nGram);
		while(itr.size()!=0) {
			NGram top = itr.remove(0);
			for(NGram ng : top.getNextWords().values()) {
				if(ng.level==n) {
					if(havingCount==0) {
						c ++;
					} else
					if(compType==0 && ng.getCount()==havingCount) {
						c ++;
					} else
					if(compType==1 && ng.getCount()>=havingCount) {
						c ++;
					} else
					if(compType==-1 && ng.getCount()<=havingCount) {
						c ++;
					}
				} else {
					itr.add(ng);
				}
			}
		}
		return c;
	}
	
}

class NGramFrequency implements Comparable<NGramFrequency>{
	
	String text;
	double count;
	
	public NGramFrequency(String text, double count) {
		this.text = text;
		this.count = count;
	}
	
	public int compareTo(NGramFrequency o) {
		if(count>o.count) 
			return 1;
		else
		if(count<o.count)
			return -1;
		else
			return 0;
	}
}