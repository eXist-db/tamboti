$(function() {
    tamboti.apis = {};
    tamboti.apis.simpleSearch = function() {
        $("#results").empty();
        $.ajax({
            url: "index.html",
            data: {
                "input1": $("#simple-search-form input[name='input1']").val(),
                "render-collection-path": $("#simple-search-form input[name='render-collection-path']").val(),
                "sort": $("#simple-search-form select[name='sort']").val(),
                "field1": $("#simple-search-form input[name='field1']").val(),
                "query-tabs": $("#simple-search-form input[name='query-tabs']").val(),
                "collection-tree": $("#simple-search-form input[name='collection-tree']").val(),
                "collection": $("#simple-search-form input[name='collection']").val()
            },
            dataType: "html",
            type: "POST",
            success: function (data) {
            	tamboti.apis._loadPaginator(data);
            }
        });
    };
    
    tamboti.apis.advancedSearch = function() {
        $("#results").empty();        
        $.ajax({
            url: "index.html",
            data: {
                "format": $("#advanced-search-form select[name='format']").val(),
                "default-operator": $("#advanced-search-form select[name='default-operator']").val(),
                "operator1": $("#advanced-search-form select[name='operator1']").val(),
                "input1": $("#advanced-search-form input[name='input1']").val(),
                "field1": $("#advanced-search-form input[name='field1']").val(),
                "render-collection-path": $("#advanced-search-form input[name='render-collection-path']").val(),
                "sort": $("#advanced-search-form select[name='sort']").val(),
                "sort-direction": $("#advanced-search-form select[name='sort-direction']").val(),
                "query-tabs": $("#advanced-search-form input[name='query-tabs']").val(),
                "collection-tree": $("#advanced-search-form input[name='collection-tree']").val(),
                "collection": $("#advanced-search-form input[name='collection']").val()
            },
            dataType: "html",
            type: "POST",
            success: function (data) {
            	tamboti.apis._loadPaginator(data);
            }
        });
    };
    
    tamboti.apis._loadPaginator = function(data) {
        $("#results-head .hit-count").text($(data).find("#results-head .hit-count").first().text());
        $("#last-collection-queried").text(" found in " + $("#simple-search-form input[name='render-collection-path']").val());
        $("#results").pagination({
            url: "retrieve",
            totalItems: $("#results-head .hit-count").text(),
            itemsPerPage: 10,
            navContainer: "#results-head .navbar",
            readyCallback: resultsLoaded,
            params: { mode: "list" }
        });
    };
});