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
import java.util.List;
import java.util.Properties;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
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

		String sourceFilename = "";
		String targetFilename = "";

		try {
			sourceFilename = System.getProperty("sourcefile");
			targetFilename = System.getProperty("targetfile");
		} catch (Exception e) {
		}

		switch (option) {
		case INDEX:
			{
				DomainFilter indexer = new DomainFilter();
				indexer.index(sourceFilename, targetFilename);
			}
			break;
		case SCORE:
			{
				DomainFilter sc = new DomainFilter();
				sc.score(sourceFilename, targetFilename);
			}
			break;
		case HELP:
		default:
			help();
		}
	}

	private void index(String sourceFilename, String targetFilename) throws FileNotFoundException, IOException {

		BufferedReader source = null;
		BufferedReader target = null;
		
		boolean sourceAvailabe = false;
		boolean targetAvailabe = false;

		if (sourceFilename != null && !sourceFilename.equals("")) {
			if (sourceFilename.endsWith(".gz") || sourceFilename.endsWith(".GZ")) {
				source = new BufferedReader(
							new InputStreamReader(new GZIPInputStream(
								new FileInputStream(sourceFilename)), Charset.forName(encoding)));
			} else {
				source = new BufferedReader(new InputStreamReader(
							new FileInputStream(sourceFilename), Charset.forName(encoding)));
			}
			sourceAvailabe = true;
		}

		if (targetFilename != null && !targetFilename.equals("")) {
			if (targetFilename.endsWith(".gz") || targetFilename.endsWith(".GZ")) {
				target = new BufferedReader(
							new InputStreamReader(new GZIPInputStream(
								new FileInputStream(targetFilename)), Charset.forName(encoding)));
			} else {
				target = new BufferedReader(new InputStreamReader(
							new FileInputStream(targetFilename), Charset.forName(encoding)));
			}
			targetAvailabe = true;
		}
		
		if(!sourceAvailabe && !targetAvailabe) {
			System.err.println("Please provide at least a source or a target corpus");
			System.exit(1);
		}

		deleteDir(new File(config.getProperty("lucene.index.directory")));

		IndexWriter writer = getWriter();

		int sentenceID = 0;
		while (true) {

			sentenceID++;
			Document doc = new Document();
			doc.add(new Field(IndexedFields.ID.toString(), String.valueOf(sentenceID), Field.Store.YES, Field.Index.NO));

			if(sourceAvailabe) {
				String sLine = source.readLine();
				if(sLine == null) break;
				doc.add(new Field(IndexedFields.SOURCE.toString(), sLine, Field.Store.YES, Field.Index.ANALYZED));				
			}

			if(targetAvailabe) {
				String tLine = target.readLine();
				if(tLine == null) break;
				doc.add(new Field(IndexedFields.TARGET.toString(), tLine, Field.Store.YES, Field.Index.ANALYZED));
			}
			
			writer.addDocument(doc);
			
		}
		
		if(sourceAvailabe) source.close();
		if(targetAvailabe) target.close();

		writer.close();
	}

	private void score(String sourceFilename, String targetFilename)
			throws FileNotFoundException, IOException, ParseException,
			InterruptedException, ExecutionException {

		BufferedReader source = null;
		BufferedReader target = null;

		boolean sourceAvailabe = false;
		boolean targetAvailabe = false;

		if (sourceFilename != null && !sourceFilename.equals("")) {
			if (sourceFilename.endsWith(".gz") || sourceFilename.endsWith(".GZ")) {
				source = new BufferedReader(
							new InputStreamReader(new GZIPInputStream(
								new FileInputStream(sourceFilename)), Charset.forName(encoding)));
			} else {
				source = new BufferedReader(new InputStreamReader(
							new FileInputStream(sourceFilename), Charset.forName(encoding)));
			}
			sourceAvailabe = true;
		}

		if (targetFilename != null && !targetFilename.equals("")) {
			if (targetFilename.endsWith(".gz") || targetFilename.endsWith(".GZ")) {
				target = new BufferedReader(
							new InputStreamReader(new GZIPInputStream(
								new FileInputStream(targetFilename)), Charset.forName(encoding)));
			} else {
				target = new BufferedReader(new InputStreamReader(
							new FileInputStream(targetFilename), Charset.forName(encoding)));
			}
			targetAvailabe = true;
		}
		
		if(!sourceAvailabe && !targetAvailabe) {
			System.err.println("Please provide at least a source or a target corpus");
			System.exit(1);
		}
		
		BufferedWriter outputWriter = new BufferedWriter(new OutputStreamWriter(System.out, Charset.forName(encoding)));
		String outputFormat[] = config.getProperty("output.format").split("\\|");
		OutputFields outputFields[] = new OutputFields[outputFormat.length];
		String delimiter = config.getProperty("output.seperator");
		for (int i = 0; i < outputFormat.length; i++) {
			outputFields[i] = OutputFields.valueOf(outputFormat[i]);
		}

		BooleanQuery.setMaxClauseCount(Integer.MAX_VALUE);
		
		String sLine = "";
		String tLine = "";

		Hashtable<String, Result> results = new Hashtable<String, Result>();

		ArrayList<String> sLines = new ArrayList<String>();
		ArrayList<String> tLines = new ArrayList<String>();
		
		while (true) {

			if(sourceAvailabe) {
				sLine = source.readLine();
				if(sLine == null) break;
				sLines.add(sLine);
			}
			
			if(targetAvailabe) {
				tLine = target.readLine();
				if(tLine == null) break;
				tLines.add(tLine);
			}
			
		}
		
		if(sourceAvailabe) source.close();
		if(targetAvailabe) target.close();

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

		ExecutorService threadPool = Executors.newCachedThreadPool();
		List<Future<Boolean>> callbacks = new ArrayList<Future<Boolean>>();
		
		int corpusSize = Math.max(sLines.size(), tLines.size());
		
		for (int k=0;k<corpusSize;k+=1000) {
			int start = k;
			int end = k+1000;
			if(end > corpusSize) {
				end = corpusSize;
			}
			callbacks.add(threadPool.submit(new SearchTask(start, end, sLines, tLines, ngramUpto, results, nbest, indexReader)));			
		}
		
		threadPool.shutdown();
		
		for(Future<Boolean> callback : callbacks) {
			callback.get();
		}

		ArrayList<Result> sortedResults = new ArrayList<Result>(results.values());

		Collections.sort(sortedResults);

		for (int n = 0; n < outputLines & n < sortedResults.size(); n++) {

			Result doc = sortedResults.get(n);

			int i = 0;
			
			for (i = 0; i < outputFields.length - 1; i++) {
				outputWriter.write(doc.get(outputFields[i]));
				outputWriter.write(delimiter);
			}

			outputWriter.write(doc.get(outputFields[i]));
			outputWriter.newLine();
			outputWriter.flush();
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
			for (int i = 0; i < children.length; i++) {
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

		// if anything passed from command line override
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
		} catch (Exception e) {

		}

	}

	private static void help() {
		System.out.println("Usage: ");
		System.exit(1);
	}
	
}

enum IndexedFields {
	ID, SOURCE, TARGET
}

enum OutputFields {
	ID, SCORE, SOURCE, TARGET
}

enum Options {
	INDEX, SCORE, HELP
}

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

class SearchTask implements Callable<Boolean> {
	
	int start;
	int end;
	ArrayList<String> sLines;
	ArrayList<String> tLines;
	int ngramUpto;
	Hashtable<String, Result> results;
	IndexReader indexReader;
	int nbest;
	
	int whichSide = -1;
	
	public SearchTask(int start, int end, ArrayList<String> sLines, ArrayList<String> tLines, int ngramUpto,
			Hashtable<String, Result> results, int nbest, IndexReader indexReader) {
		this.start = start;
		this.end = end;
		this.sLines = sLines;
		this.tLines = tLines;
		this.ngramUpto = ngramUpto;
		this.results = results;
		this.nbest = nbest;
		this.indexReader = indexReader;
		
		if(sLines.size()>0 && tLines.size()>0) {
			whichSide = 2;
		} else if(sLines.size()>0) {
			whichSide = 0;
		} else {
			whichSide = 1;
		}
		
	}

	@Override
	public Boolean call() throws Exception {
		
		//QueryParser parserSrc = new QueryParser(DomainFilter.luceneVersion, IndexedFields.SOURCE.toString(), new StandardAnalyzer(DomainFilter.luceneVersion));
		//QueryParser parserTrg = new QueryParser(DomainFilter.luceneVersion, IndexedFields.TARGET.toString(), new StandardAnalyzer(DomainFilter.luceneVersion));
		
		for (int k = start; k < end; k++) {
			String sl = "";
			String tl = "";
			
			BooleanQuery query = new BooleanQuery();
			
			if(whichSide == 0 || whichSide == 2) {
				sl = sLines.get(k);
				
				NGramExtractor ngramExtractor = new NGramExtractor(ngramUpto);
				ngramExtractor.calculateNGrams(sl);
	
				ArrayList<String> ngrams = ngramExtractor.getNGramsUpto(ngramUpto);
				for (String ngram : ngrams) {
					query.add(new TermQuery(new Term(IndexedFields.SOURCE.toString(), ngram)), Occur.SHOULD);
				}
				/*try {
					query.add(parserSrc.parse(sl), Occur.SHOULD);
				}catch(ParseException e) {				
				}*/
			}			

			if(whichSide == 1 || whichSide == 2) {
				tl = tLines.get(k);
				NGramExtractor ngramExtractor = new NGramExtractor(ngramUpto);
				ngramExtractor.calculateNGrams(tl);
	
				ArrayList<String> ngrams = ngramExtractor.getNGramsUpto(ngramUpto);
				for (String ngram : ngrams) {
					query.add(new TermQuery(new Term(IndexedFields.TARGET.toString(), ngram)), Occur.SHOULD);
				}			
				/*try{
					query.add(parserTrg.parse(tl), Occur.SHOULD);
				}catch(ParseException e) {				
				}*/
			}

			IndexSearcher searcher = new IndexSearcher(indexReader);

			TopDocs matches = null;

			matches = searcher.search(query, nbest);

			for (ScoreDoc scoreDoc : matches.scoreDocs) {
				Document document = searcher.doc(scoreDoc.doc);
				String documentID = document.get(IndexedFields.ID.toString());
				float score = scoreDoc.score / matches.getMaxScore();
				synchronized (results) {
					if (results.containsKey(documentID)) {
						Result prevScore = results.get(documentID);
						prevScore.setScore(prevScore.getScore() + score);
					} else {
						results.put(documentID, new Result(document, score));
					}
					System.err.println(documentID + "\t" + score);
				}
			}
			
			searcher.close();

		}
		return true;
	}
	
}