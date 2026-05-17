#if UNITY_IOS
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.iOS.Xcode;

namespace NativeAudioHelper.Editor
{
    // Links MediaPlayer.framework on top of Unity's default frameworks. The native
    // plugin uses MPVolumeView + MPVolumeSlider for programmatic system-volume
    // changes; Unity does not auto-link MediaPlayer for non-audio projects.
    public sealed class PostProcessorIOS : IPostprocessBuildWithReport
    {
        int IOrderedCallback.callbackOrder => 2;

        public void OnPostprocessBuild(BuildReport report)
        {
            if (report.summary.platform != BuildTarget.iOS) return;

            string projPath = PBXProject.GetPBXProjectPath(report.summary.outputPath);
            var project = new PBXProject();
            project.ReadFromFile(projPath);

            string[] targets =
            {
                project.GetUnityMainTargetGuid(),
                project.GetUnityFrameworkTargetGuid()
            };

            foreach (string targetGuid in targets)
            {
                project.AddFrameworkToProject(targetGuid, "MediaPlayer.framework", false);
            }

            project.WriteToFile(projPath);
        }
    }
}
#endif
