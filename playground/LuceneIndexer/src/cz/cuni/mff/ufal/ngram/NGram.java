package cz.cuni.mff.ufal.ngram;

import java.util.Hashtable;

class NGram {
	
	/* The word that this part of the n-gram represent */
	String word = null;

	/* Level is the position of the word in the n-gram 
	 * e.g. if "I am" is a bi-gram and this current instance of NGram represent "am"
	 * the level will contain the value 2 */
	int level = 0;

	/* The frequency of a particular n-gram according to the level 
	 * if the level is 1 the count will be the frequency of uni-gram 
	 * if the level is 2 the count will be the frequency of bi-gram and so on */
	int count = 0;
	
	/* The Hashtable of nextWord will store the reference of all words follow this word in an n-gram 
	 * in the context of tree structure this will be the list of child of current node */
	Hashtable<String, NGram> nextWord = null;
	
	public NGram(String word) {
		this.word = word;
		this.count = 1;
		nextWord = new Hashtable<String, NGram> ();
	}
	
	public NGram(String word, int level) {
		this(word);
		this.level = level;		
	}

	
	public void increment() {
		count ++;
	}
	
	/* Add a new child to the current node */
	public NGram addWord(String word) {
		NGram item = nextWord.get(word);
		if(item==null)
			item = new NGram(word);
		else
			item.increment();
		nextWord.put(word, item);
		return item;
	}
	
	public int getCount() {
		return count;
	}
	
	public Hashtable<String, NGram> getNextWords() {
		return nextWord;
	}
	
	
	public double getFrequency(String ... text) {
		double count = 0;
		Hashtable<String, NGram> current = nextWord;						
		NGram nGram = null;
		try{
			for(int i=0;i<text.length;i++) {
				nGram = current.get(text[i]);
				current = nGram.getNextWords();
			}
			count = nGram.count;
		} catch(Exception e) {
					count = 0;
		}
		
		return count;
	}
}