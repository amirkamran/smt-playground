import java.util.ArrayList;

import cz.cuni.mff.ufal.ngram.NGramExtractor;


public class Test {

	public static void main(String args[]) {
		String str = "this is a test sentence to test the functionality of ngram extractor";
		NGramExtractor nge = new NGramExtractor(5);
		nge.calculateNGrams(str);
		ArrayList<String> triGrams = nge.getNGramsUpto(5);
		for(String s : triGrams) {
			System.out.println(s);
		}
	}
	
}
