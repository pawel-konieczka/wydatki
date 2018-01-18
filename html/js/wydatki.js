
var FIELDNAME_ID = 'id';
var FIELDNAME_DATE = 'date';
var FIELDNAME_VALUE = 'value';
var FIELDNAME_DESCR = 'description';
var FIELDNAME_CATEGORY = 'category';
var FIELDNAME_AUTHOR = 'author';
var FIELDNAME_DISCOUNT = 'discount';
var FIELDNAME_DETAILS = 'details';

var compareDate = function(el1, el2) {
    return hashCompare(el1, el2, FIELDNAME_DATE);
}

var compareValue = function(el1, el2) {
    return hashCompareNum(el1, el2, FIELDNAME_VALUE);
}

var compareDescription = function(el1, el2) {
    return hashCompare(el1, el2, FIELDNAME_DESCR);
}

var compareCategory = function(el1, el2) {
    return hashCompare(el1, el2, FIELDNAME_CATEGORY);
}

var compareAuthor = function(el1, el2) {
    return hashCompare(el1, el2, FIELDNAME_AUTHOR);
}

function hashCompare(el1, el2, hash) {
    return el1[hash].localeCompare(el2[hash]);
}

function hashCompareNum(el1, el2, hash) {
    return  el1[hash] - el2[hash];
}

function sort(name, asc, el) {
    setProgress('on');

    setSortStyle(el, asc);

    setTimeout(sort_async, 100, [name], [asc]);
}

function sort_async(name, asc) {
    if(name == FIELDNAME_DATE) {
	report.sort(compareDate);
    } else if(name == FIELDNAME_VALUE) {
	report.sort(compareValue);
    } else if(name == FIELDNAME_DESCR) {
	report.sort(compareDescription);
    } else if(name == FIELDNAME_CATEGORY) {
	report.sort(compareCategory);
    } else if(name == FIELDNAME_AUTHOR) {
	report.sort(compareAuthor);
    } 

    if(asc == 0) {
	report.reverse();
    }


    displayReplist(report);


    updateFilter('sort', name + ( asc == 0 ? '-desc' : '-asc') );
    setProgress('off');
}

function setSortStyle(el, asc) {
    while($('#sort-desc-on').attr("id") != null) {
	$('#sort-desc-on').attr("id", "bttn-sort")
    }
    while($('#sort-asc-on').attr("id") != null) {
	$('#sort-asc-on').attr("id", "bttn-sort")
    }

    el.attr("id", "sort-" + (asc == 0 ? 'desc' : 'asc') + '-on');
}

function displayReplist(list) {
    var table = $('#outcomes_list');

    var sum = table.find('tr:last');
    sum.remove();

    while(table.prop("rows").length > 1) {
	table.find('tr:last').remove();
    }

    var counter = 0;
    for(i=0; i<list.length; ++i) {
	var style = (counter % 2) ? 'even' : 'odd';
	addRowReplist(table, list[i], style);
	counter++;
    }

    table.append(sum);

    $(".value").autoNumeric('init', {aSep: ' ', aDec: '.'});
}

function addRowReplist(table, row, style) {
    var tr = $('<tr>').attr('class', style + (row['discount'] == 1 ? ' discounted' : ''));
    
    tr.append($('<td>').text(row[FIELDNAME_DATE]));

    tr.append($('<td>').text(row[FIELDNAME_VALUE]).attr('class', 'value'));

    var descrCell = $('<td>').append($('<a>')
				     .attr('href', 'wydatki.cgi?rm=auth_edit_item_html&id=' + row['id'])
				     .text(row[FIELDNAME_DESCR])
				    )
	.attr('class', 'description');
    if(row[FIELDNAME_DETAILS] != '') {
	descrCell.append($("<div id='details' onclick='showDetails($(this))' onmouseout='showDetails($(this))'>")
			 .append($("<span id='details_mark'>"))
			 .append($("<div id='details_text' class='details_hide'>")
				 .text(row[FIELDNAME_DETAILS]))
	);
    }
    tr.append(descrCell);

    tr.append($('<td>').text(row[FIELDNAME_CATEGORY]));

    tr.append($('<td>').text(row[FIELDNAME_AUTHOR]));

    table.append(tr);
}

function setCategory(categoryId) {
   var categories = $('#categories');
    categories.prop("selectedIndex", categoryId - 1);
}

function getCategory(descr) {
    $.post('',
	   {
	       rm: 'auth_get_category_for_descr', 
	       description: descr
	   },
	   function(data, status, response) {
	       var categoryId = response.responseText || 'blank';
	       setCategory(categoryId);
	   }
	  );
}


function updateFilter(filterName, filterValue) {
    $.post('', 
	   {
	       rm: 'auth_update_filter', 
	       fname: filterName, 
	       fvalue: filterValue
	   }
	  );
}

function setProgress(state, message) {
    var pb = $('#progress-bar');
    var visibility = state == 'on' ? 'visible' : (state == 'off' ? 'hidden' : '');
    pb.css("visibility", visibility);
}

function showDetails(element) {
    var nodes = element.find('#details_text');
    nodes.each(function() {
	$(this).attr('class', $(this).attr('class') == 'details_show' ? 'details_hide' : 'details_show');
    });
}

function validateFilter() {
    // na razie puste
    return true;
}

function removeFilter() {
    var f = document.filter;
    f.year.value = (new Date).getFullYear();
    f.month.value = (new Date).getMonth() + 1;
    f.category.value = 0;
    f.user.value = 0;
    f.description.value = "";
    f.discount.value = "";
    f.discount[2].checked = true;
    f.date_from.value = "";
    f.date_to.value = "";
    changeFilterDateState(0);
    f.submit();
}

function showExtendedFilter(updateSession) {
    var showFilter = $('#show_extended_filter');
    var hideFilter = $('#hide_extended_filter');
    var extendedFilter = $('#extended_filter');

    extendedFilter.css("visibility", "visible");
    showFilter.css("visibility", "collapse");
    hideFilter.css("visibility", "visible");

    if(updateSession == 1) {
	updateFilter('extended', 1);
    }
}

function hideExtendedFilter() {
    var showFilter = $('#show_extended_filter');
    var hideFilter = $('#hide_extended_filter');
    var extendedFilter = $('#extended_filter');

    extendedFilter.css("visibility", "collapse");
    showFilter.css("visibility", "visible");
    hideFilter.css("visibility", "collapse");

    updateFilter('extended', 0);
}

function changeFilterDateState(checked) {
    var element = $('#filter-date');
    var fLabel = element.find('#filter-label');
    if(checked == 1) {
	fLabel.prop('checked', true);
    } else if(checked == 0) {
	fLabel.prop('checked', false);
    }

    if(fLabel.prop('checked')) {
	$('#filter-form input[name=date_enabled]').val(1);
	element.removeClass('disabled');
	element.find('#filter-definition input').attr('disabled', false);
	$('#filter-month select').attr('disabled', true);
    } else {
	$('#filter-form input[name=date_enabled]').val(0);
	element.addClass('disabled');
	element.find('#filter-definition input').attr('disabled', true);
	$('#filter-month select').attr('disabled', false);
    }
}