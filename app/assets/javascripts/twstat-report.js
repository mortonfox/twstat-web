/*jslint white: true, browser: true */

function draw_by_month(month_data, month_min, month_max) {
    "use strict";

    // Create and populate the data table.
    var data = new google.visualization.DataTable();
    data.addColumn('date', 'Month');
    data.addColumn('number', 'Count');
    data.addColumn({type:'string', role:'tooltip', p: {html: true}});
    data.addRows(month_data);

    // Create and draw the visualization.
    new google.visualization.ColumnChart(document.getElementById('by_month')).draw(data,
	{
	    title : "Tweets by Month",
	    width : 1200, 
	    height : 400,
	    legend : {
		position: 'none'
	    },
	    tooltip : {
		isHtml : true 
	    },
	    hAxis: {
		gridlines: { 
		    color: 'transparent'
		},
		title: "Month", 
		viewWindowMode: 'explicit', viewWindow: {
		    max: month_max, min: month_min
		}
	    }
	}
    );
}

function draw_by_dow(dow_data, chart_title, elemid) {
    "use strict";

    // Create and populate the data table.
    var data = new google.visualization.DataTable();
    data.addColumn('string', 'Day of Week');
    data.addColumn('number', 'Count');
    data.addColumn({type:'string', role:'tooltip', p: {html: true}});
    data.addRows(dow_data);

    // Create and draw the visualization.
    new google.visualization.ColumnChart(document.getElementById(elemid)).draw(data,
	{
	    title : chart_title,
	    width : 600, 
	    height : 400,
	    legend: {position: 'none'},
	    tooltip : {
		isHtml : true 
	    },
	    hAxis: {
		title: "Day of Week", 
		gridlines:{ color: 'transparent'}
	    }
	}
    );
}

function draw_by_hour(hour_data, chart_title, elemid) {
    "use strict";

    // Create and populate the data table.
    var data = new google.visualization.DataTable();
    data.addColumn('number', 'Hour');
    data.addColumn('number', 'Count');
    data.addColumn({type:'string', role:'tooltip', p: {html: true}});
    data.addRows(hour_data);

    // Create and draw the visualization.
    new google.visualization.ColumnChart(document.getElementById(elemid)).draw(data,
	{
	    title : chart_title,
	    width : 600, 
	    height : 400,
	    legend: {position: 'none'},
	    tooltip: { isHtml: true },
	    hAxis: {
		baselineColor: 'transparent',
		title: 'Hour',
		gridlines:{ color: 'transparent'},
		viewWindowMode: 'explicit', viewWindow: {
		    max: 23.5, min: -0.5
		}
	    }
	}
    );
}

function draw_by_mention(mention_data, chart_title, elemid) {
    "use strict";

    // Create and populate the data table.
    var data = new google.visualization.DataTable();
    data.addColumn('string', 'User');
    data.addColumn('number', 'Count');
    data.addRows(mention_data);

    // Create and draw the visualization.
    new google.visualization.BarChart(document.getElementById(elemid)).draw(data,
	{
	    title : chart_title,
	    width : 600, 
	    height : 400,
	    legend: {position: 'none'},
	    hAxis: {
		viewWindowMode: 'explicit', viewWindow: {
		    min: 0
		}
	    }
	}
    );
}

function cloud_by_words(words_data, elemid) {
    "use strict";
    $("#" + elemid).jQCloud(words_data);
}


