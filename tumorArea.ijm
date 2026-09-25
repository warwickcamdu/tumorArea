Dialog.create("tumorArea");
Dialog.addDirectory("Input directory:", "");
Dialog.addString("Image Sequence Filter", "B3_02_1_");
Dialog.addNumber("Cell diameter for Cellpose:", 40);
Dialog.addNumber("Minimum diameter (um):", 30);
Dialog.addNumber("Scale (um/pixel):", 0.5);
Dialog.show();

input = Dialog.getString();
filter = Dialog.getString();
cellDiam = Dialog.getNumber();
minMajor = Dialog.getNumber();
scale = Dialog.getNumber();
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
File.makeDirectory(input+File.separator+"Results");

run("CLIJ2 Macro Extensions", "cl_device=");
run("ROI Manager...");
setBatchMode("hide");
for (j = 1; j <= 25; j++) {
	if(File.exists(input+File.separator+filter+j+"Z0_Bright Field_001.tif")){
	File.openSequence(input, " filter="+filter+j+"Z");
	// CLIJ2 EOF Sobel filter
	image1=getTitle();
	Ext.CLIJ2_push(image1);
	image2 = "EOF_sobel";
	sigma = 10.0;
	Ext.CLIJ2_extendedDepthOfFocusSobelProjection(image1, image2, sigma);
	Ext.CLIJ2_pull(image2);
	saveAs("Tiff", input+File.separator+"Results"+File.separator+filter+j+"_Processed.tif");
	// Cellpose find tumors
	run("Cellpose...", "cp_model=yeast_BF_cp3 custom_model= cell_diameter="+cellDiam+" cyto_channel=1 nuclei_channel=None min_size=0 normalize=true resample=true return_rois=true cellprob_threshold=0.0 flow_threshold=0.4 tile_overlap=0.1 niter=0 compute_flows=false shuffle=true mode_3d=None stitch_threshold=0.0 flow3d_smooth=0 torchversion=cpu usegpu=false");
	// Scale to um and measure
	run("Set Scale...", "distance=1 known="+scale+" unit=um");
	run("Set Measurements...", "area centroid fit shape redirect=None decimal=9");
	roiManager("Measure");
	// Filter ROIs based on roundness and diameter
	n = roiManager("count");
	if (n == 0) exit("ROI Manager is empty.");
	for (i = 0; i < n; i++) {
    	roiManager("select", i);
    	run("Measure");
	}
	for (i = n - 1; i >= 0; i--) {
    	roundness = getResult("Round", i);
    	major = getResult("Major", i);

    	if (roundness < 0.6 || major < minMajor) {
        	roiManager("select", i);
        	roiManager("delete");
    	}
	}
	selectWindow("Results");
	run("Close");
	// Remeasure with only essential measurements
	run("Set Measurements...", "area centroid display redirect=None decimal=9");
	roiManager("Deselect");
	roiManager("Measure");
	// Save results
	setBatchMode("show");
	saveAs("Results", input+File.separator+"Results"+File.separator+filter+j+"_Results.csv");
	roiManager("Save", input+File.separator+"Results"+File.separator+filter+j+"_RoiSet.zip");
	//setBatchMode("show");
	//Clear everything before opening next image sequence
	selectWindow("Results");
	run("Close");
	roiManager("reset");
	close("*");
	}
}
// Save parameters
params = "tumorArea\n" +
    "Date: " + year +"-"+ month +"-"+ dayOfMonth +" "+ hour +":"+ minute +"\n"+
    "Input directory: "+input+"\n" +
    "Filter: "+filter+"\n"+
    "Cell diameter for Cellpose: " + cellDiam+"\n"+
    "Minimum diameter (um): " + minMajor+"\n"+
    "Scale (um/pixel): " + scale+"\n"
print(params)
File.saveString(params, input+File.separator+"Results" +File.separator+"Parameters.txt");