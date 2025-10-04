String title          = 'Salesforce Developer';
String location       = 'Raleigh, NC';
Integer radius        = 25;
Integer page          = 1;
Integer resultsPerPage= 10;

// -------- Call the API
HttpResponse res = JoobleCallout.search(title, location, radius, page, resultsPerPage);