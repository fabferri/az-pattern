package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type Cast struct {
	Actor1, Actor2, Actor3 string
}

type Moview struct {
	Id, Title, Genre, Director, Author, Music, Posterfile string
	Year                                                  int
	Team                                                  []Cast
}

func main() {

	credential := options.Credential{
		Username: "superAdmin",
		Password: "Verdicchio**2016",
	}
	clientOpts := options.Client().ApplyURI("mongodb://10.0.1.10:27017").
		SetAuth(credential)
	// mongo.Connect return mongo.Client method
	client, err := mongo.Connect(context.TODO(), clientOpts)
	if err != nil {
		log.Fatalf("Failed to connect to the MongoDB server: %v", err)
	}

	// Release resource when the main function is returned.
	defer func() {
		if err = client.Disconnect(context.TODO()); err != nil {
			log.Fatal(err)
		}
	}()

	// ctx will be used to set deadline for process
	ctx, _ := context.WithTimeout(context.Background(), 10*time.Second)

	// Force a connection to verify our connection string
	// mongo.Client has Ping to ping mongoDB, deadline of the Ping method will be determined by cxt
	// Ping method return error if any occurred, then the error can be handled.
	err = client.Ping(ctx, nil)
	if err != nil {
		log.Fatalf("Failed to ping MongoDB: %v", err)
	}

	// List databases
	databases, err := client.ListDatabaseNames(ctx, bson.M{})
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(databases)

	// Reading All Documents from a Collection
	moviesCollection := client.Database("dbmovies").Collection("listmovies")
	cursor, err := moviesCollection.Find(ctx, bson.M{})
	if err != nil {
		log.Fatalf("Failed to run find all documents in the collection listmovies: %v", err)
	}

	// MongoDB stores documents in a binary representation called BSON
	// The Go Driver provides four main types for working with BSON data:
	// D: An ordered representation of a BSON document (slice)
	// M: An unordered representation of a BSON document (map)
	// A: An ordered representation of a BSON array
	// E: A single element inside a D type
	//
	//
	// bson.M represents a map of fields in no particular order.
	// However, because we're trying to return all documents, there aren't any fields in our query.
	// Assuming no error happens, the results will exist in a MongoDB cursor.
	// In this simple example, all documents are decoded into a []bson.M variable, the cursor is closed, and then the variable is printed.
	var movies []bson.M
	if err = cursor.All(ctx, &movies); err != nil {
		log.Fatal(err)
	}
	fmt.Println(movies)

	// Reading a Single Document from a Collection
	// a FindOne is executed without any particular query filter on the data.
	// Rather than returning a cursor, the single result can be decoded directly into the bson.M object
	var docu bson.M
	if err = moviesCollection.FindOne(ctx, bson.M{}).Decode(&docu); err != nil {
		log.Fatal(err)
	}
	fmt.Println(docu)

	// Querying Documents from a Collection with a Filter
	fmt.Println("\nsingle document with a filter:")
	filterCursor, err := moviesCollection.Find(ctx, bson.M{"Director": "Sergio Leone"})
	if err != nil {
		log.Fatalf("Failed to find a single document with filter: %v", err)
	}
	var docsFiltered []bson.M
	if err = filterCursor.All(ctx, &docsFiltered); err != nil {
		log.Fatal(err)
	}
	fmt.Println(docsFiltered)

	// Sorting Documents in a Query
	fmt.Println("\nsorting:")
	opts := options.Find()
	opts.SetSort(bson.D{{"Year", -1}})
	sortCursor, err := moviesCollection.Find(ctx, bson.D{{"Year", bson.D{{"$gt", 1960}}}}, opts)
	if err != nil {
		log.Fatal(err)
	}
	var moviesSorted []bson.M
	if err = sortCursor.All(ctx, &moviesSorted); err != nil {
		log.Fatal(err)
	}
	fmt.Println(moviesSorted)

	//
	//
	//
	fmt.Println("\nlist movies:")
	cursor, err = moviesCollection.Find(context.TODO(), bson.D{{}})
	if err != nil {
		log.Fatal(err)
	}
	var myMovies []Moview
	if err = cursor.All(context.TODO(), &myMovies); err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Found multiple documents: %+v\n", myMovies)

	// Insert multiple documents
	movie1 := Moview{Id: "P000701",
		Title:      "The Ten Commandments",
		Genre:      "religious",
		Year:       1956,
		Director:   "Cecil B. DeMille",
		Author:     "Dorothy Clarke Wilson,  J. H. Ingraham",
		Music:      "Elmer Bernstein",
		Posterfile: "",
		Team: []Cast{
			Cast{
				Actor1: "Charlton Heston",
				Actor2: "Yul Brynner",
				Actor3: "Anne Baxter",
			},
			Cast{
				Actor1: "Edward G. Robinson",
				Actor2: "Yvonne De Carlo",
				Actor3: "",
			},
		},
	}
	movie2 := Moview{Id: "P000704",
		Title:      "From Russia with Love",
		Genre:      "spy fiction",
		Year:       1956,
		Director:   "Terence Young",
		Author:     "Ian Fleming",
		Music:      "John Barry",
		Posterfile: "",
		Team: []Cast{
			Cast{
				Actor1: "Sean Connery",
				Actor2: "Pedro Armendáriz",
				Actor3: "Lotte Lenya",
			},
			Cast{
				Actor1: "Robert Shaw",
				Actor2: "",
				Actor3: "",
			},
		},
	}
	multipleDocs := []interface{}{movie1, movie2}

	insertManyResult, err := moviesCollection.InsertMany(context.TODO(), multipleDocs)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("Inserted multiple documents: ", insertManyResult.InsertedIDs)

}
