package cz.cuni.mff.ufal.languagetools;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.charset.Charset;
import java.util.Iterator;
import java.util.List;
import edu.stanford.nlp.ling.HasWord;
import edu.stanford.nlp.process.DocumentPreprocessor;
import edu.stanford.nlp.process.DocumentPreprocessor.DocType;

public class SentenceSplitter {

	public static void main(String args[]) throws IOException {
		
		BufferedWriter out = new BufferedWriter(new OutputStreamWriter(new FileOutputStream("/Users/amirkamran/Desktop/sportsCorpusSplitted.txt"), Charset.forName("UTF-8")));
		BufferedReader in = new BufferedReader(new InputStreamReader(new FileInputStream("/Users/amirkamran/Desktop/sportsCorpus.txt"), Charset.forName("UTF-8")));
		
		DocumentPreprocessor dp = new DocumentPreprocessor(in, DocType.Plain);
		dp.setEncoding("UTF-8");

		Iterator<List<HasWord>> itr = dp.iterator();
		while(itr.hasNext()) {
			List<HasWord> sentence = itr.next();
			try{
				for(int i=0;i<sentence.size()-1;i++) {
					HasWord word = sentence.get(i);
					//System.out.print(word + " ");
					out.append(word.toString()).append(" ");
				}
				out.append(sentence.get(sentence.size()-1).toString());
				//System.out.print(sentence.get(sentence.size()-1));
			}catch(ArrayIndexOutOfBoundsException e) {
			}
			out.append("\n");
			out.flush();
			//System.out.println();
		}
		out.close();
	}
	
}
