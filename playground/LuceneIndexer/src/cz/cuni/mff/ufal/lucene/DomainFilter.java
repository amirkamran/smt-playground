package cz.cuni.mff.ufal.lucene;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.lang.reflect.InvocationTargetException;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Hashtable;
import java.util.Properties;
import java.util.zip.GZIPInputStream;

import org.apache.lucene.analysis.Analyzer;
import org.apache.lucene.document.Document;
import org.apache.lucene.document.Field;
import org.apache.lucene.index.CorruptIndexException;
import org.apache.lucene.index.IndexReader;
import org.apache.lucene.index.IndexWriter;
import org.apache.lucene.index.IndexWriterConfig;
import org.apache.lucene.index.Term;
import org.apache.lucene.queryParser.ParseException;
import org.apache.lucene.search.BooleanClause.Occur;
import org.apache.lucene.search.BooleanQuery;
import org.apache.lucene.search.IndexSearcher;
import org.apache.lucene.search.ScoreDoc;
import org.apache.lucene.search.TermQuery;
import org.apache.lucene.search.TopDocs;
import org.apache.lucene.store.Directory;
import org.apache.lucene.store.FSDirectory;
import org.apache.lucene.util.Version;

import cz.cuni.mff.ufal.ngram.NGramExtractor;

public class DomainFilter {

	static Properties config = new Properties();
	static Version luceneVersion = Version.LUCENE_35;
	Analyzer analyzer = null;
	String encoding = "UTF8";

	public DomainFilter() throws IllegalArgumentException, SecurityException,
			InstantiationException, IllegalAccessException,
			InvocationTargetException, NoSuchMethodException,
			ClassNotFoundException {
		String analyzerClass = config.getProperty("lucene.analyzer");
		luceneVersion = Version.valueOf(config.getProperty("lucene.version"));
		analyzer = (Analyzer) Class.forName(analyzerClass)
				.getConstructor(new Class[] { Version.class })
				.newInstance(luceneVersion);
		encoding = config.getProperty("encoding");
	}

	public static void main(String args[]) throws Exception {
		loadConfig();
		Options option = Options.HELP;
		try {
			option = Options.valueOf(args[0].toUpperCase());
		} catch (Exception e) {
			help();
		}
		
		String filename = "";
		
		try{
			filename = System.getProperty("inputfile");
		} catch(Exception e) {			
		}
		
		switch (option) {
		case INDEX:
			DomainFilter indexer = new DomainFilter();
			indexer.index(filename);
			break;
		case SCORE:
			DomainFilter sc1 = new DomainFilter();
			sc1.score(filename, false);
			break;
		case SCORE_SENTENCE:
			DomainFilter sc2 = new DomainFilter();
			sc2.score(filename, true);
			break;
		case HELP:
		default:
			help();
		}
	}

	private void index(String filename) throws FileNotFoundException,
			IOException {
		BufferedReader input = null;
		boolean consoleInput = false;
		
		if(filename!=null && !filename.equals("")) {		
			if (filename.endsWith(".gz") || filename.endsWith(".GZ")) {
				input = new BufferedReader(new InputStreamReader(
						new GZIPInputStream(new FileInputStream(filename)), Charset.forName(encoding)));
			} else {
				input = new BufferedReader(new InputStreamReader(
						new FileInputStream(filename), Charset.forName(encoding)));
			}
		} else {
			input = new BufferedReader(new InputStreamReader(System.in, Charset.forName(encoding)));
			consoleInput = true;
		}
		deleteDir(new File(config.getProperty("lucene.index.directory")));
		
		IndexWriter writer = getWriter();

		String line = "";
		int sentenceID = 0;
		while ((line = input.readLine()) != null && !(consoleInput && line.equals(""))) {
			sentenceID++;
			Document doc = new Document();
			doc.add(new Field(IndexedFields.ID.toString(),
					String.valueOf(sentenceID), Field.Store.YES,
					Field.Index.NO));
			doc.add(new Field(IndexedFields.TEXT.toString(), line,
					Field.Store.YES, Field.Index.ANALYZED));
			writer.addDocument(doc);
		}
		input.close();

		writer.close();
	}

	private void score(String filename, boolean sentenceBySentence) throws FileNotFoundException,
			IOException, ParseException {
		BufferedReader input = null;
		boolean consoleInput = false;
		int i = 0;
		
		BufferedWriter outputWriter = new BufferedWriter(new OutputStreamWriter(System.out, Charset.forName(encoding)));
		String outputFormat[] = config.getProperty("output.format").split("\\|");
		OutputFields outputFields[] = new OutputFields[outputFormat.length];
		String delimiter = config.getProperty("output.seperator");
		for (i = 0; i < outputFormat.length; i++) {
			outputFields[i] = OutputFields.valueOf(outputFormat[i]);
		}

		
		if(filename!=null && !filename.equals("")) {		
			if (filename.endsWith(".gz") || filename.endsWith(".GZ")) {
				input = new BufferedReader(new InputStreamReader(
						new GZIPInputStream(new FileInputStream(filename)), Charset.forName(encoding)));
			} else {
				input = new BufferedReader(new InputStreamReader(
						new FileInputStream(filename), Charset.forName(encoding)));
			}
		} else {
			input = new BufferedReader(new InputStreamReader(System.in, Charset.forName(encoding)));
			consoleInput = true;
		}

		// StringBuilder queryString = new StringBuilder();

		BooleanQuery.setMaxClauseCount(Integer.MAX_VALUE);
		String line = "";

		Hashtable<String, Result> results = new Hashtable<String, Result>();

		ArrayList<String> lines = new ArrayList<String>();
		while ((line = input.readLine()) != null && !(consoleInput && line.equals(""))) {
			lines.add(line);
		}
		input.close();

		IndexReader indexReader = getReader();
		
		
		int outputLines = Integer.MAX_VALUE;

		try {
			outputLines = Integer.parseInt(config.getProperty("output.lines"));
		} catch (Exception e) {
			
		}

		if (outputLines == 0)
			outputLines = Integer.MAX_VALUE;
	
		int ngramUpto = 1;
		try {
			ngramUpto = Integer.parseInt(config.getProperty("query.ngram.upto"));
		} catch (Exception e) {
			
		}
		
		int nbest = 1;
		try {
			nbest = Integer.parseInt(config.getProperty("score.nbest"));
		} catch (Exception e) {
			
		}
		

		for (String l : lines) {

			NGramExtractor ngramExtractor = new NGramExtractor(ngramUpto);
			ngramExtractor.calculateNGrams(l);

			BooleanQuery query = new BooleanQuery();

			ArrayList<String> ngrams = ngramExtractor.getNGramsUpto(ngramUpto);
			for (String ngram : ngrams) {
				// queryString.append('"').append(ngram.toString()).append('"').append(" OR ");
				query.add(new TermQuery(new Term(IndexedFields.TEXT.toString(),
						ngram)), Occur.SHOULD);
			}

			// QueryParser parser = new QueryParser(luceneVersion,
			// IndexedFields.TEXT.toString(), analyzer);
			// Query query = parser.parse(queryString.substring(0,
			// queryString.length()-4));

			IndexSearcher searcher = new IndexSearcher(indexReader);

			TopDocs matches = null;
			
			if(sentenceBySentence) {
				matches = searcher.search(query, nbest);
			} else {
				matches = searcher.search(query, outputLines);
			}
			// System.out.println("Query # " + ++i + " :: Hits=" +
			// matches.totalHits + " :: MaxScore=" + matches.getMaxScore());

			for (ScoreDoc scoreDoc : matches.scoreDocs) {
				Document document = searcher.doc(scoreDoc.doc);
				String documentID = document.get(IndexedFields.ID.toString());
								
				if(sentenceBySentence) {
					Result doc = new Result(document, scoreDoc.score);	

					for (i = 0; i < outputFields.length - 1; i++) {
						outputWriter.write(doc.get(outputFields[i]));
						outputWriter.write(delimiter);
					}
		
					outputWriter.write(doc.get(outputFields[i]));
					outputWriter.newLine();
					outputWriter.flush();					
					
				} else {				
					float score = scoreDoc.score / lines.size();
					if (results.containsKey(documentID)) {
						Result prevScore = results.get(documentID);
						prevScore.setScore(prevScore.getScore() + score);
					} else {
						results.put(documentID, new Result(document, score));
					}
					
				}
			}
			
			if(sentenceBySentence) outputWriter.newLine();

		}
		
		if(!sentenceBySentence) {

			ArrayList<Result> sortedResults = new ArrayList<Result>(
					results.values());
	
			Collections.sort(sortedResults);
				
			for (int n = 0; n < outputLines & n < sortedResults.size(); n++) {
	
				Result doc = sortedResults.get(n);
	
				for (i = 0; i < outputFields.length - 1; i++) {
					outputWriter.write(doc.get(outputFields[i]));
					outputWriter.write(delimiter);
				}
	
				outputWriter.write(doc.get(outputFields[i]));
				outputWriter.newLine();
				outputWriter.flush();
			}
		}
		
		outputWriter.close();
	}

	private IndexWriter getWriter() throws IOException {
		Directory directory = FSDirectory.open(new File(config
				.getProperty("lucene.index.directory")));
		IndexWriterConfig iConfig = new IndexWriterConfig(luceneVersion,
				analyzer);
		return new IndexWriter(directory, iConfig);
	}

	private IndexReader getReader() throws CorruptIndexException, IOException {
		Directory directory = FSDirectory.open(new File(config
				.getProperty("lucene.index.directory")));
		return IndexReader.open(directory, true);
	}
	
	public static boolean deleteDir(File dir) {
	    if (dir.isDirectory()) {
	        String[] children = dir.list();
	        for (int i=0; i<children.length; i++) {
	            boolean success = deleteDir(new File(dir, children[i]));
	            if (!success) {
	                return false;
	            }
	        }
	    }

	    // The directory is now empty so delete it
	    return dir.delete();
	}
	
	private static void loadConfig() throws IOException {
		String configFile = "";
		try {
			configFile = System.getProperty("config");
		} catch (Exception e) {
		}
		if (configFile == null || configFile.isEmpty()) {
			configFile = "config.properties";
		}
		FileReader configFileReader = new FileReader(configFile);
		config.load(configFileReader);
		configFileReader.close();
		
		//if anything passed from command line override
		try {
			String temp = System.getProperty("lucene.index.directory");
			config.setProperty("lucene.index.directory", temp);
		} catch (Exception e) {
		}

		try {
			String temp = System.getProperty("query.ngram.upto");
			config.setProperty("query.ngram.upto", temp);
		} catch (Exception e) {
		}
		
		try {
			String temp = System.getProperty("output.lines");
			config.setProperty("output.lines", temp);
		} catch (Exception e) {
		}
		
		System.getProperties();
		
		try {
			String temp = System.getProperty("output.format");
			config.setProperty("output.format", temp);
		} catch (Exception e) {
		}

		try {
			String temp = System.getProperty("output.seperator");
			config.setProperty("output.seperator", temp);
		} catch (Exception e) {
		}

		try {
			String temp = System.getProperty("inputfile");
			config.setProperty("inputfile", temp);
		} catch (Exception e) {
		}

		try {
			String temp = System.getProperty("encoding");
			config.setProperty("encoding", temp);
		} catch (Exception e) {
		}
		
		try {
			String temp = System.getProperty("score.nbest");
			config.setProperty("score.nbest", temp);
		} catch(Exception e) {
			
		}

	}

	private static void help() {
		System.out.println("Usage: ");
		System.exit(1);
	}

	enum IndexedFields {
		ID, TEXT
	};

	enum OutputFields {
		ID, TEXT, SCORE
	};

	enum Options {
		INDEX, SCORE, SCORE_SENTENCE, HELP
	};

	class Result implements Comparable<Result> {

		private float score;
		private Document document;

		public Result(Document document, float score) {
			this.document = document;
			this.score = score;
		}

		public Document getDocument() {
			return document;
		}

		public float getScore() {
			return score;
		}

		public void setScore(float score) {
			this.score = score;
		}

		@Override
		public int compareTo(Result o) {
			// return Float.compare(score, o.score); //ascending
			return Float.compare(o.score, score); // descending
		}

		public String get(OutputFields field) {
			switch (field) {
			case SCORE:
				return String.valueOf(this.score);
			default:
				return document.get(field.toString());
			}
		}

	}

}