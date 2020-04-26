/* -*- mode: groovy -*-
  Confgure how to run our job in Jenkins.
  See https://github.com/castle-engine/castle-engine/wiki/Cloud-Builds-(Jenkins) .
*/

pipeline {
  agent {
    docker {
      image 'kambi/castle-engine-cloud-builds-tools:cge-none'
    }
  }
  environment {
    /* Used by CGE build tool ("castle-engine").
       Define env based on another env variable.
       According to https://github.com/jenkinsci/pipeline-model-definition-plugin/pull/110
       this should be supported. */
    CASTLE_ENGINE_PATH = "${WORKSPACE}"
  }
  stages {
    stage('Build Tools (Default FPC)') {
      steps {
        sh 'make clean tools'
      }
    }

    stage('Build Examples (Default FPC)') {
      steps {
	/* clean 1st, to make sure it's OK even when state is "clean" before "make examples" */
	sh 'make clean examples'
      }
    }
    stage('Build Examples Using Lazarus (Default FPC/Lazarus)') {
      steps {
	sh 'make clean examples-laz'
      }
    }
    stage('Build And Run Auto-Tests (Default FPC)') {
      steps {
	sh 'export PATH="${PATH}:${CASTLE_ENGINE_PATH}/tools/build-tool/" && make tests'
      }
    }
    stage('Build Using FpMake (Default FPC)') {
      steps {
	sh 'make clean build-using-fpmake'
      }
    }

    /* Same with FPC 3.0.2.
       We could use a script to reuse the code,
       but then the detailed time breakdown/statistics would not be available in Jenkins. */

    stage('Build Tools (FPC 3.0.2)') {
      steps {
	sh 'source /usr/local/fpclazarus/bin/setup.sh 3.0.2 && make clean tools'
      }
    }
    stage('Build Examples (FPC 3.0.2)') {
      steps {
	/* clean 1st, to make sure it's OK even when state is "clean" before "make examples" */
	sh 'source /usr/local/fpclazarus/bin/setup.sh 3.0.2 && make clean examples'
      }
    }
    stage('Build Examples Using Lazarus (FPC 3.0.2/Lazarus)') {
      steps {
	sh 'source /usr/local/fpclazarus/bin/setup.sh 3.0.2 && make clean examples-laz'
      }
    }
    stage('Build And Run Auto-Tests (FPC 3.0.2)') {
      steps {
	sh 'source /usr/local/fpclazarus/bin/setup.sh 3.0.2 && export PATH="${PATH}:${CASTLE_ENGINE_PATH}/tools/build-tool/" && make tests'
      }
    }
    stage('Build Using FpMake (FPC 3.0.2)') {
      steps {
	sh 'source /usr/local/fpclazarus/bin/setup.sh 3.0.2 && make clean build-using-fpmake'
      }
    }

    /* Same with FPC trunk.
       We could use a script to reuse the code,
       but then the detailed time breakdown/statistics would not be available in Jenkins. */

    stage('Build Tools (FPC trunk)') {
      steps {
	sh 'source /usr/local/fpclazarus/bin/setup.sh trunk && make clean tools'
      }
    }
    stage('Build Examples (FPC trunk)') {
      steps {
	/* clean 1st, to make sure it's OK even when state is "clean" before "make examples" */
	sh 'source /usr/local/fpclazarus/bin/setup.sh trunk && make clean examples'
      }
    }
    stage('Build Examples Using Lazarus (FPC trunk/Lazarus)') {
      steps {
	sh 'source /usr/local/fpclazarus/bin/setup.sh trunk && make clean examples-laz'
      }
    }
    stage('Build And Run Auto-Tests (FPC trunk)') {
      steps {
	sh 'source /usr/local/fpclazarus/bin/setup.sh trunk && export PATH="${PATH}:${CASTLE_ENGINE_PATH}/tools/build-tool/" && make tests'
      }
    }
    stage('Build Using FpMake (FPC trunk)') {
      steps {
	sh 'source /usr/local/fpclazarus/bin/setup.sh trunk && make clean build-using-fpmake'
      }
    }

    stage('Pack Release') {
      steps {
        sh 'rm -f castle-engine*.zip' /* remove previous artifacts */
        sh './tools/internal/pack_release/pack_release.sh'
      }
    }
    /* update Docker image only when the "master" branch changes */
    stage('Update Docker Image with CGE') {
      when { branch 'master' }
      steps {
        build job: '../castle_game_engine_update_docker_image'
      }
    }
  }
  post {
    success {
      archiveArtifacts artifacts: 'castle-engine*.zip'
    }
    regression {
      mail to: 'michalis@castle-engine.io',
        subject: "[jenkins] Build started failing: ${currentBuild.fullDisplayName}",
        body: "See the build details on ${env.BUILD_URL}"
    }
    failure {
      mail to: 'michalis@castle-engine.io',
        subject: "[jenkins] Build failed: ${currentBuild.fullDisplayName}",
        body: "See the build details on ${env.BUILD_URL}"
    }
    fixed {
      mail to: 'michalis@castle-engine.io',
        subject: "[jenkins] Build is again successfull: ${currentBuild.fullDisplayName}",
        body: "See the build details on ${env.BUILD_URL}"
    }
  }
}
