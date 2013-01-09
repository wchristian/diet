function intake_callback(org_content,value,settings) {
    var res=value.substring(0,5);
    var date=".kcal"+$(this).attr("class").substring(5);
    if(res=="Error") {
        $(this).text(org_content);
        $("#messages").html("<p class='error'><br /><img src='images/error.png' alt='Error' /> "+value.substring(6)+"</p>").fadeIn(10).fadeTo(3000,1).fadeTo(1000,0)
    }
    else {
        $(this).text(value.substring(2));
        $("#messages").html("<p class='ok'><br /><img src='images/tick.png' alt='OK' /> Edit successful</p>").fadeIn(10).fadeTo(3000,1).fadeTo(1000,0);
        if(value.substring(0,2)=='c:') {
            $(".graphs").html("<img src='view_intake_graph.pl' alt='Intake Graph' /><img src='view_intake_split_graph.pl' alt='Intake Split Graph' />");
            var new_kcal=value.substring(2);
            var old_total=$(date).text();
            var new_total=parseInt(old_total)+parseInt(new_kcal)-parseInt(org_content);
            $(date).hide();
            $(date).text(new_total);
            $(date).slideDown("slow")
        }
    }
}

function weight_callback(org_content,value,settings) {
    var res=value.substring(0,5);
    if(res=="Error"){
        $(this).text(org_content);
        $("#messages").html("<p class='error'><br /><img src='images/error.png' alt='Error' /> "+value.substring(6)+"</p>").fadeIn(10).fadeTo(3000,1).fadeTo(1000,0)}else{$("#messages").html("<p class='ok'><br /><img src='images/tick.png' alt='OK' /> Edit successful</p>").fadeIn(10).fadeTo(3000,1).fadeTo(1000,0);
        $(".graphs").html("<img src='view_weights_graph.pl' alt='Weight Graph' />")
    }
}