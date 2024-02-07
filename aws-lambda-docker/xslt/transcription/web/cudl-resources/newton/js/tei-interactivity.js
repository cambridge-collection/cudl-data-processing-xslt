;($(document).ready(function() {

var new_tooltip = $.widget("custom.ttip", $.ui.tooltip, {
	options: {
		parent_tooltip_contents: '',
		content: function() {
			// support: IE<9, Opera in jQuery <1.7
			// .text() can't accept undefined, so coerce to a string
			var title = $(this).attr("ui-tooltip-title") || $(this).attr("title");
			// Escape title, since we're going from an attribute to raw HTML

			$.custom.ttip.prototype.options.parent_tooltip_contents = "<p>" + title + "</p>" + $.custom.ttip.prototype.options.parent_tooltip_contents;
			return $.custom.ttip.prototype.options.parent_tooltip_contents;
		},
		hide: true,
		// Disabled elements have inconsistent behavior across browsers (#8661)
		items: "[title]:not([disabled])",
		position: {
			my: "left top+15",
			at: "left bottom",
			collision: "flipfit flip"
		},
		show: true,
		tooltipClass: 'custom_ttip',
		track: false,

		// callbacks
		close: function(elem, ui) {
			$.custom.ttip.prototype.options.parent_tooltip_contents = '';
			$('[aria-relevant="additions"][aria-live="assertive"][role="log"]').html('');
		},
		open: null
	},
	open: function(event) {
		var that = this,
			target = $(event ? event.target : this.element)
			// we need closest here due to mouseover bubbling,
			// but always pointing at the same event target
			.closest(this.options.items);
		//this.close();
		// No element to show a tooltip for or the tooltip is already open
		if (!target.length || target.data("ui-tooltip-id")) {
			return;
		}

		if (target.attr("title")) {
			target.data("ui-tooltip-title", target.attr("title"));
		}

		target.data("ui-tooltip-open", true);

		// kill parent tooltips, custom or native, for hover
		if (event && event.type === "mouseover") {
			target.parents().each(function() {
				var parent = $(this),
					blurEvent;
				if (parent.data("ui-tooltip-open")) {
					blurEvent = $.Event("blur");
					blurEvent.target = blurEvent.currentTarget = this;
					that.close(blurEvent, true);
				}
				if (parent.attr("title")) {
					parent.uniqueId();
					that.parents[this.id] = {
						element: this,
						title: parent.attr("title")
					};
					parent.attr('ui-tooltip-title', parent.attr("title"));
					parent.attr("title", "");
				}
				if (parent.attr("ui-tooltip-title")) {
					$.custom.ttip.prototype.options.parent_tooltip_contents += "<p>" + parent.attr("ui-tooltip-title") + "</p>";
				}
			});
		}

		this._registerCloseHandlers(event, target);
		this._updateContent(target, event);
	}
});

  $('[title]').mouseover(function() {
    $(this).addClass('hover');
    $('.hover').last().addClass('focus');
  });
  $('[title]').mouseout(function() {
    $('.hover').removeClass('hover');
    $('.focus').removeClass('focus');
  });
  $('#tei,#endnotes').ttip({track: true }); // is this one even needed?

$('#switcher_link').attr('title','').ttip({
    track: true,
    content: function() {
      return $('#switcherHelp').html();
    }
  });
  $('sup.note, span.note').click(function() {
    display_note(this);
  });

  $('.expandable .label').hover(function() {
    $(this).toggleClass("hover");
  });
  $('.expandable .label').click(function(event) {
    var object = $(this);
    var parent = $(this).parent();
    event.stopPropagation();
    var submenu = parent.children("ul").length > 0 ? parent.children("ul").first() : parent.find(".wrapper");
    submenu.slideToggle('fast');
    icon = object.children(".ui-icon");
    icon.toggleClass("ui-icon-triangle-1-e");
    icon.toggleClass("ui-icon-triangle-1-s");
  });
  $('li.expandable ul, li.expandable .wrapper').css('display', 'none');


$( ".pagination .first" ).button({text: false, icons: { primary: "ui-icon-arrowthickstop-1-w" }});
$( ".pagination .previous" ).button({text: false, icons: {primary: "ui-icon-arrowthick-1-w"}});
$( ".pagination .next" ).button({text: false, icons: {primary: "ui-icon-arrowthick-1-e"}});
$( ".pagination .last" ).button({text: false,icons: {primary: "ui-icon-arrowthickstop-1-e"}});
$( ".pagination .page" ).button();
$( ".pagination span.first, .pagination span.previous, .pagination span.next, .pagination span.last " ).button( "option", "disabled", true );
$( "span.selected" ).removeClass('ui-state-disabled').addClass('ui-state-highlight');
})
);

function display_note(obj) {
  var anchor = $(obj);
  var anchor_id = anchor.attr('id');
  var note_id = anchor_id.substring(0, anchor_id.indexOf('-'));
  var note = $("#" + note_id);
  var title = $('#' + anchor_id).text();
  var is_numeric = (parseInt(title, 10) == title);
  if (is_numeric) {
    title = "Note: " + title;
  }

  note.dialog({
    "title": title,
    "height": 'auto',
    "width": 'auto',
    "resizable": false,
    'closeOnEscape': true
  }).dialog('widget').position({
    my: 'left top',
    at: 'right bottom',
    of: anchor,
    collision: "flip flip"
  });

  var flipV = 'flip';
  var flipH = 'flip';

  flipH = (note.offset().left <= 0) ? 'fit' : 'flip';
  var flip = flipH + " " + flipV;
  var note_width = note.width();
  note_width += note_width * 0.05;
  max_width = (note_width > 789) ? 600 : note_width;

  note.dialog('option', {
    width: max_width
  }).dialog('widget').position({
    my: 'left top',
    at: 'right bottom',
    of: anchor,
    collision: flip
  });
}

function create_viewer(image_obj) {
    var images = [];
    var image_name = image_obj.image_info;
    var image_number = image_obj.image_number;

    for (index = 0; index < image_name.length; ++index) {
    images.push('/resources/images/pages/'+image_name[index].file);
    }

    History.Adapter.bind(window,'statechange',function(){
        var State = History.getState();
    });
    function update_facs_header_and_url(viewer, image_obj) {
        $('#header > h1>#opening_name').html(image_obj.image_info[viewer.currentPage()].name);
    History.pushState(null, $('h1.page_title').text(), "?page="+(viewer.currentPage()+1))
    }
    // Call seadragon with images
    var viewer = OpenSeadragon({
        id: "image_viewer",
        prefixUrl: "/resources/images/openseadragon/",
        tileSources: images,
        sequenceMode: (images.length > 1),
        showFullPageControl: true,
        initialPage: image_number,
        showRotationControl: true
    });
    if ($(location).attr('href').indexOf('/view/images/') !=-1) {
    viewer.nextButton.addHandler('click', function (event) { update_facs_header_and_url(viewer, image_obj) });
    viewer.previousButton.addHandler('click', function (event) { update_facs_header_and_url(viewer, image_obj) });
    }
}
